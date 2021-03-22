package stretch;

import stretch.Result;

using stretch.IteratorTools;
using stretch.NumberTools;

// machine epsilon
private inline final EPSILON = 2.2204460492503130808472633361816E-16;
private inline final MIN_FLOAT = -1.7976931348623157E+308;

class Stretch {
	public static function computeLayout(root:Node, size:Size<Number>) {
		var style = root.style;
		var hasRootMinMax =
			style.minSize.width.isDefined()
			|| style.minSize.height.isDefined()
			|| style.maxSize.width.isDefined()
			|| style.maxSize.height.isDefined();

		var result = if (hasRootMinMax) {
			var firstPass = computeInternal(root, style.size.resolve(size), size, false);
			computeInternal(
				root,
				{
					width: firstPass
						.size
						.width
						.maybeMax(style.minSize.width.resolve(size.width))
						.maybeMin(style.maxSize.width.resolve(size.width))
						.into(),
					height: firstPass
						.size
						.height
						.maybeMax(style.minSize.height.resolve(size.height))
						.maybeMin(style.maxSize.height.resolve(size.height))
						.into(),
				},
				size,
				true
			);
		} else {
			computeInternal(root, style.size.resolve(size), size, true);
		}

		root.layout = {
			order: 0,
			size: result.size,
			location: Point.zero()
		}

		roundLayout(root, 0.0, 0.0);
	}

	static function roundLayout(root:Node, absX:Float, absY:Float) {
		var layout = root.layout;
		var absX = absX + layout.location.x;
		var absY = absY + layout.location.y;

		// TODO: rust rounds half-way cases away from zero
		layout.location.x = Math.fround(layout.location.x);
		layout.location.y = Math.fround(layout.location.y);
		layout.size.width = Math.fround(absX + layout.size.width) - Math.round(absX);
		layout.size.height = Math.fround(absY + layout.size.height) - Math.round(absY);

		if (root.children != null)
			for (child in root.children) {
				roundLayout(child, absX, absY);
			}
	}

	static function computeInternal(node:Node, nodeSize:Size<Number>, parentSize:Size<Number>, performLayout:Bool):ComputeResult {
		node.isDirty = false;

		// First we check if we have a result for the given input
		var cache = node.layoutCache;
		if (cache != null) {
			if (cache.performLayout || !performLayout) {
				var widthCompatible = if (nodeSize.width.isDefined())
					Math.abs(nodeSize.width.getDefined() - cache.result.size.width) < EPSILON
				else
					cache.nodeSize.width.isUndefined();

				var heightCompatible = if (nodeSize.height.isDefined())
					Math.abs(nodeSize.height.getDefined() - cache.result.size.height) < EPSILON
				else
					cache.nodeSize.height.isUndefined();

				if (widthCompatible && heightCompatible) {
					return cache.result.clone();
				}

				if (cache.nodeSize.eq(nodeSize) && cache.parentSize.eq(parentSize)) {
					return cache.result.clone();
				}
			}
		}

		// Define some general constants we will need for the remainder
		// of the algorithm.
		var dir = node.style.flexDirection;
		var isRow = dir.isRow();
		var isColumn = dir.isColumn();
		var isWrapReverse = node.style.flexWrap == WrapReverse;

		var margin = node.style.margin.map(n -> n.resolve(parentSize.width).orElse(0.0));
		var padding = node.style.padding.map(n -> n.resolve(parentSize.width).orElse(0.0));
		var border = node.style.border.map(n -> n.resolve(parentSize.width).orElse(0.0));

		var paddingBorder:Rect<Float> = {
			start: padding.start + border.start,
			end: padding.end + border.end,
			top: padding.top + border.top,
			bottom: padding.bottom + border.bottom,
		};

		var nodeInnerSize:Size<Number> = {
			width: nodeSize.width - paddingBorder.horizontal(),
			height: nodeSize.height - paddingBorder.vertical(),
		};

		var containerSize = Size.zero();
		var innerContainerSize = Size.zero();

		// If this is a leaf node we can skip a lot of this function in some cases
		if (node.children == null || node.children.length == 0) {
			if (nodeSize.width.isDefined() && nodeSize.height.isDefined()) {
				return new ComputeResult(nodeSize.map(s -> s.orElse(0.0)));
			}

			var measure = node.measure;
			if (measure != null) {
				var result = new ComputeResult(measure(nodeSize));
				node.layoutCache = {
					nodeSize: nodeSize,
					parentSize: parentSize,
					performLayout: performLayout,
					result: result.clone()
				};
				return result;
			}

			return new ComputeResult({
				width: nodeSize.width.orElse(0.0) + paddingBorder.horizontal(),
				height: nodeSize.height.orElse(0.0) + paddingBorder.vertical(),
			});
		}

		// 9.2. Line Length Determination

		// 1. Generate anonymous flex items as described in §4 Flex Items.

		// 2. Determine the available main and cross space for the flex items.
		//    For each dimension, if that dimension of the flex container’s content box
		//    is a definite size, use that; if that dimension of the flex container is
		//    being sized under a min or max-content constraint, the available space in
		//    that dimension is that constraint; otherwise, subtract the flex container’s
		//    margin, border, and padding from the space available to the flex container
		//    in that dimension and use that value. This might result in an infinite value.

		var availableSpace:Size<Number> = {
			width: nodeSize.width.orElse(parentSize.width - margin.horizontal()) - paddingBorder.horizontal(),
			height: nodeSize.height.orElse(parentSize.height - margin.vertical()) - paddingBorder.vertical(),
		};

		var flexItems = node.children
			.iterator()
			.filter(child -> child.style.positionType != Absolute)
			.filter(child -> child.style.display != None)
			.map(child -> ({
				node: child,
				size: child.style.size.resolve(nodeInnerSize),
				minSize: child.style.minSize.resolve(nodeInnerSize),
				maxSize: child.style.maxSize.resolve(nodeInnerSize),

				position: child.style.position.map(p -> p.resolve(nodeInnerSize.width)),
				margin: child.style.margin.map(m -> m.resolve(nodeInnerSize.width).orElse(0.0)),
				padding: child.style.padding.map(p -> p.resolve(nodeInnerSize.width).orElse(0.0)),
				border: child.style.border.map(b -> b.resolve(nodeInnerSize.width).orElse(0.0)),

				flexBasis: 0.0,
				innerFlexBasis: 0.0,
				violation: 0.0,
				frozen: false,

				hypotheticalInnerSize: Size.zero(),
				hypotheticalOuterSize: Size.zero(),
				targetSize: Size.zero(),
				outerTargetSize: Size.zero(),

				baseline: 0.0,

				offsetMain: 0.0,
				offsetCross: 0.0,
			} : FlexItem))
			.collect();

		var hasBaselineChild = flexItems
			.iterator()
			.any(child -> child.node.style.getAlignSelf(node.style) == Baseline);

		// TODO - this does not follow spec. See commented out code below
		// 3. Determine the flex base size and hypothetical main size of each item:
		for (child in flexItems) {
			var childStyle = child.node.style;

			// A. If the item has a definite used flex basis, that’s the flex base size.

			var flexBasis = childStyle.flexBasis.resolve(nodeInnerSize.main(dir));
			if (flexBasis.isDefined()) {
				child.flexBasis = flexBasis.orElse(0.0);
				continue;
			};

			// B. If the flex item has an intrinsic aspect ratio,
			//    a used flex basis of content, and a definite cross size,
			//    then the flex base size is calculated from its inner
			//    cross size and the flex item’s intrinsic aspect ratio.

			if (childStyle.aspectRatio.isDefined()) {
				var cross = nodeSize.cross(dir);
				if (cross.isDefined()) {
					if (childStyle.flexBasis == Auto) {
						child.flexBasis = cross.getDefined() * childStyle.aspectRatio.getDefined();
						continue;
					}
				}
			}

			// C. If the used flex basis is content or depends on its available space,
			//    and the flex container is being sized under a min-content or max-content
			//    constraint (e.g. when performing automatic table layout [CSS21]),
			//    size the item under that constraint. The flex base size is the item’s
			//    resulting main size.

			// TODO - Probably need to cover this case in future

			// D. Otherwise, if the used flex basis is content or depends on its
			//    available space, the available main size is infinite, and the flex item’s
			//    inline axis is parallel to the main axis, lay the item out using the rules
			//    for a box in an orthogonal flow [CSS3-WRITING-MODES]. The flex base size
			//    is the item’s max-content main size.

			// TODO - Probably need to cover this case in future

			// E. Otherwise, size the item into the available space using its used flex basis
			//    in place of its main size, treating a value of content as max-content.
			//    If a cross size is needed to determine the main size (e.g. when the
			//    flex item’s main size is in its block axis) and the flex item’s cross size
			//    is auto and not definite, in this calculation use fit-content as the
			//    flex item’s cross size. The flex base size is the item’s resulting main size.

			var width = if (!child.size.width.isDefined()
				&& childStyle.getAlignSelf(node.style) == Stretch
				&& isColumn)
			{
				availableSpace.width;
			} else {
				child.size.width;
			}

			var height = if (!child.size.height.isDefined()
				&& childStyle.getAlignSelf(node.style) == Stretch
				&& isRow)
			{
				availableSpace.height;
			} else {
				child.size.height;
			}

			child.flexBasis = computeInternal(
					child.node,
					{
						width: width.maybeMax(child.minSize.width).maybeMin(child.maxSize.width),
						height: height.maybeMax(child.minSize.height).maybeMin(child.maxSize.height)
					},
					availableSpace,
					false
				)
				.size
				.main(dir)
				.maybeMax(child.minSize.main(dir))
				.maybeMin(child.maxSize.main(dir));
		}

		// The hypothetical main size is the item’s flex base size clamped according to its
		// used min and max main sizes (and flooring the content box size at zero).

		for (child in flexItems) {
			child.innerFlexBasis = child.flexBasis - child.padding.main(dir) - child.border.main(dir);

			// TODO - not really spec abiding but needs to be done somewhere. probably somewhere else though.
			// The following logic was developed not from the spec but by trail and error looking into how
			// webkit handled various scenarios. Can probably be solved better by passing in
			// min-content max-content constraints from the top
			var minMain = computeInternal(child.node, Size.undefined(), availableSpace, false)
				.size
				.main(dir)
				.maybeMax(child.minSize.main(dir))
				.maybeMin(child.size.main(dir))
				.into();

			child
				.hypotheticalInnerSize
				.setMain(dir, child.flexBasis.maybeMax(minMain).maybeMin(child.maxSize.main(dir)));

			child
				.hypotheticalOuterSize
				.setMain(dir, child.hypotheticalInnerSize.main(dir) + child.margin.main(dir));
		}

		// 9.3. Main Size Determination

		// 5. Collect flex items into flex lines:
		//    - If the flex container is single-line, collect all the flex items into
		//      a single flex line.
		//    - Otherwise, starting from the first uncollected item, collect consecutive
		//      items one by one until the first time that the next collected item would
		//      not fit into the flex container’s inner main size (or until a forced break
		//      is encountered, see §10 Fragmenting Flex Layout). If the very first
		//      uncollected item wouldn’t fit, collect just it into the line.
		//
		//      For this step, the size of a flex item is its outer hypothetical main size. (Note: This can be negative.)
		//      Repeat until all flex items have been collected into flex lines
		//
		//      Note that the "collect as many" line will collect zero-sized flex items onto
		//      the end of the previous line even if the last non-zero item exactly "filled up" the line.

		var flexLines = {
			var lines:Array<FlexLine> = [];

			if (node.style.flexWrap == NoWrap) {
				lines.push({ items: flexItems, crossSize: 0.0, offsetCross: 0.0 });
			} else {
				var flexItems = flexItems.copy(); // TODO: is [..] copy?

				while (flexItems.length > 0) {
					var lineLength = 0.0;
					var index = flexItems
						.keyValueIterator()
						.find(o -> {
							lineLength += o.value.hypotheticalOuterSize.main(dir);
							var main = availableSpace.main(dir);
							if (main.isDefined()) {
								lineLength > main.getDefined() && o.key != 0;
							} else {
								false;
							}
						});
					var index = if (index != null) index.key else flexItems.length;

					var items = flexItems.slice(0, index);
					var rest = flexItems.slice(index, flexItems.length);
					lines.push({ items: items, crossSize: 0.0, offsetCross: 0.0 });
					flexItems = rest;
				}
			}

			lines;
		};

		// 6. Resolve the flexible lengths of all the flex items to find their used main size.
		//    See §9.7 Resolving Flexible Lengths.
		//
		// 9.7. Resolving Flexible Lengths

		for (line in flexLines) {
			// 1. Determine the used flex factor. Sum the outer hypothetical main sizes of all
			//    items on the line. If the sum is less than the flex container’s inner main size,
			//    use the flex grow factor for the rest of this algorithm; otherwise, use the
			//    flex shrink factor.

			var usedFlexFactor = line.items.iterator().map(child -> child.hypotheticalOuterSize.main(dir)).sum();
			var growing = usedFlexFactor < nodeInnerSize.main(dir).orElse(0.0);
			var shrinking = !growing;

			// 2. Size inflexible items. Freeze, setting its target main size to its hypothetical main size
			//    - Any item that has a flex factor of zero
			//    - If using the flex grow factor: any item that has a flex base size
			//      greater than its hypothetical main size
			//    - If using the flex shrink factor: any item that has a flex base size
			//      smaller than its hypothetical main size

			for (child in line.items) {
				// TODO - This is not found by reading the spec. Maybe this can be done in some other place
				// instead. This was found by trail and error fixing tests to align with webkit output.
				if (nodeInnerSize.main(dir).isUndefined() && isRow) {
					child.targetSize.setMain(
						dir,
						computeInternal(
							child.node,
							{
								width: child.size.width.maybeMax(child.minSize.width).maybeMin(child.maxSize.width),
								height: child
									.size
									.height
									.maybeMax(child.minSize.height)
									.maybeMin(child.maxSize.height),
							},
							availableSpace,
							false
						)
						.size
						.main(dir)
						.maybeMax(child.minSize.main(dir))
						.maybeMin(child.maxSize.main(dir))
					);
				} else {
					child.targetSize.setMain(dir, child.hypotheticalInnerSize.main(dir));
				}

				// TODO this should really only be set inside the if-statement below but
				// that causes the targetMainSize to never be set for some items

				child.outerTargetSize.setMain(dir, child.targetSize.main(dir) + child.margin.main(dir));

				var childStyle = child.node.style;
				if ((childStyle.flexGrow == 0.0 && childStyle.flexShrink == 0.0)
					|| (growing && child.flexBasis > child.hypotheticalInnerSize.main(dir))
					|| (shrinking && child.flexBasis < child.hypotheticalInnerSize.main(dir)))
				{
					child.frozen = true;
				}
			}

			// 3. Calculate initial free space. Sum the outer sizes of all items on the line,
			//    and subtract this from the flex container’s inner main size. For frozen items,
			//    use their outer target main size; for other items, use their outer flex base size.

			var usedSpace = line
				.items
				.iterator()
				.map(child -> {
					child.margin.main(dir) + if (child.frozen) child.targetSize.main(dir) else child.flexBasis;
				})
				.sum();

			var initialFreeSpace = (nodeInnerSize.main(dir) - usedSpace).orElse(0.0);

			// 4. Loop

			while (true) {
				// a. Check for flexible items. If all the flex items on the line are frozen,
				//    free space has been distributed; exit this loop.

				if (line.items.iterator().all(child -> child.frozen)) {
					break;
				}

				// b. Calculate the remaining free space as for initial free space, above.
				//    If the sum of the unfrozen flex items’ flex factors is less than one,
				//    multiply the initial free space by this sum. If the magnitude of this
				//    value is less than the magnitude of the remaining free space, use this
				//    as the remaining free space.

				var usedSpace = line
					.items
					.iterator()
					.map(child -> {
						child.margin.main(dir)
							+ if (child.frozen) child.targetSize.main(dir) else child.flexBasis;
					})
					.sum();


				var unfrozen = [for (child in line.items) if (!child.frozen) child];

				var sumFlexGrow = 0.0, sumFlexShrink = 0.0;
				for (item in unfrozen) {
					var style = item.node.style;
					sumFlexGrow += style.flexGrow;
					sumFlexShrink += style.flexShrink;
				}

				var freeSpace = if (growing && sumFlexGrow < 1.0) {
					(initialFreeSpace * sumFlexGrow).maybeMin(nodeInnerSize.main(dir) - usedSpace);
				} else if (shrinking && sumFlexShrink < 1.0) {
					(initialFreeSpace * sumFlexShrink).maybeMax(nodeInnerSize.main(dir) - usedSpace);
				} else {
					(nodeInnerSize.main(dir) - usedSpace).orElse(0.0);
				};

				// c. Distribute free space proportional to the flex factors.
				//    - If the remaining free space is zero
				//        Do Nothing
				//    - If using the flex grow factor
				//        Find the ratio of the item’s flex grow factor to the sum of the
				//        flex grow factors of all unfrozen items on the line. Set the item’s
				//        target main size to its flex base size plus a fraction of the remaining
				//        free space proportional to the ratio.
				//    - If using the flex shrink factor
				//        For every unfrozen item on the line, multiply its flex shrink factor by
				//        its inner flex base size, and note this as its scaled flex shrink factor.
				//        Find the ratio of the item’s scaled flex shrink factor to the sum of the
				//        scaled flex shrink factors of all unfrozen items on the line. Set the item’s
				//        target main size to its flex base size minus a fraction of the absolute value
				//        of the remaining free space proportional to the ratio. Note this may result
				//        in a negative inner main size; it will be corrected in the next step.
				//    - Otherwise
				//        Do Nothing

				if (freeSpace != 0.0) {
					if (growing && sumFlexGrow > 0.0) {
						for (child in unfrozen) {
							child.targetSize.setMain(
								dir,
								child.flexBasis
									+ freeSpace * (child.node.style.flexGrow / sumFlexGrow)
							);
						}
					} else if (shrinking && sumFlexShrink > 0.0) {
						var sumScaledShrinkFactor = unfrozen
							.iterator()
							.map(child -> child.innerFlexBasis * child.node.style.flexShrink)
							.sum();

						if (sumScaledShrinkFactor > 0.0) {
							for (child in unfrozen) {
								var scaledShrinkFactor =
									child.innerFlexBasis * child.node.style.flexShrink;
								child.targetSize.setMain(
									dir,
									child.flexBasis + freeSpace * (scaledShrinkFactor / sumScaledShrinkFactor)
								);
							}
						}
					}
				}

				// d. Fix min/max violations. Clamp each non-frozen item’s target main size by its
				//    used min and max main sizes and floor its content-box size at zero. If the
				//    item’s target main size was made smaller by this, it’s a max violation.
				//    If the item’s target main size was made larger by this, it’s a min violation.

				var totalViolation = unfrozen.iterator().fold(0.0, (acc, child) -> {
					// TODO - not really spec abiding but needs to be done somewhere. probably somewhere else though.
					// The following logic was developed not from the spec but by trail and error looking into how
					// webkit handled various scenarios. Can probably be solved better by passing in
					// min-content max-content constraints from the top. Need to figure out correct thing to do here as
					// just piling on more conditionals.
					var minMain = if (isRow && child.node.measure == null) {
						computeInternal(child.node, Size.undefined(), availableSpace, false)
							.size
							.width
							.maybeMin(child.size.width)
							.maybeMax(child.minSize.width)
							.into();
					} else {
						child.minSize.main(dir);
					};

					var maxMain = child.maxSize.main(dir);
					var clamped = Math.max(child.targetSize.main(dir).maybeMin(maxMain).maybeMax(minMain), 0.0);
					child.violation = clamped - child.targetSize.main(dir);
					child.targetSize.setMain(dir, clamped);
					child.outerTargetSize.setMain(dir, child.targetSize.main(dir) + child.margin.main(dir));

					acc + child.violation;
				});

				// e. Freeze over-flexed items. The total violation is the sum of the adjustments
				//    from the previous step ∑(clamped size - unclamped size). If the total violation is:
				//    - Zero
				//        Freeze all items.
				//    - Positive
				//        Freeze all the items with min violations.
				//    - Negative
				//        Freeze all the items with max violations.

				for (child in unfrozen) {
					switch (totalViolation) {
						case v if (v > 0.0): child.frozen = child.violation > 0.0;
						case v if (v < 0.0): child.frozen = child.violation < 0.0;
						case _: child.frozen = true;
					}
				}

				// f. Return to the start of this loop.
			}
		}

		// Not part of the spec from what i can see but seems correct
		containerSize.setMain(
			dir,
			nodeSize.main(dir).orElse({
				var longestLine = flexLines.iterator().fold(MIN_FLOAT, (acc, line) -> {
					var length = line.items.iterator().map(item -> item.outerTargetSize.main(dir)).sum();
					Math.max(acc, length);
				});

				var size = longestLine + paddingBorder.main(dir);
				var val = availableSpace.main(dir);
				if (val.isDefined() && flexLines.length > 1 && size < val.getDefined()) {
					val.getDefined();
				} else {
					size;
				}
			})
		);

		innerContainerSize.setMain(dir, containerSize.main(dir) - paddingBorder.main(dir));

		// 9.4. Cross Size Determination

		// 7. Determine the hypothetical cross size of each item by performing layout with the
		//    used main size and the available space, treating auto as fit-content.

		for (line in flexLines) {
			for (child in line.items) {
				var childCross =
					child.size.cross(dir).maybeMax(child.minSize.cross(dir)).maybeMin(child.maxSize.cross(dir));

				child.hypotheticalInnerSize.setCross(
					dir,
					computeInternal(
						child.node,
						{
							width: if (isRow) child.targetSize.width.into() else childCross,
							height: if (isRow) childCross else child.targetSize.height.into(),
						},
						{
							width: if (isRow) containerSize.main(dir).into() else availableSpace.width,
							height: if (isRow) availableSpace.height else containerSize.main(dir).into(),
						},
						false
					)
					.size
					.cross(dir)
					.maybeMax(child.minSize.cross(dir))
					.maybeMin(child.maxSize.cross(dir))
				);

				child
					.hypotheticalOuterSize
					.setCross(dir, child.hypotheticalInnerSize.cross(dir) + child.margin.cross(dir));
			}
		}

		// TODO - probably should move this somewhere else as it doesn't make a ton of sense here but we need it below
		// TODO - This is expensive and should only be done if we really require a baseline. aka, make it lazy

		function calcBaseline(node:Node, layout:Layout):Float {
			return if (node.children == null || node.children.length == 0) {
				layout.size.height;
			} else {
				var child = node.children[0];
				calcBaseline(child, child.layout);
			}
		}

		if (hasBaselineChild) {
			for (line in flexLines) {
				for (child in line.items) {
					var result = computeInternal(
						child.node,
						{
							width: if (isRow) {
								child.targetSize.width.into();
							} else {
								child.hypotheticalInnerSize.width.into();
							},
							height: if (isRow) {
								child.hypotheticalInnerSize.height.into();
							} else {
								child.targetSize.height.into();
							},
						},
						{
							width: if (isRow) containerSize.width.into() else nodeSize.width,
							height: if (isRow) nodeSize.height else containerSize.height.into(),
						},
						true
					);

					child.baseline = calcBaseline(
						child.node,
						{
							order: node.children.iterator().position(n -> n == child.node),
							size: result.size,
							location: Point.zero(),
						}
					);
				}
			}
		}

		// 8. Calculate the cross size of each flex line.
		//    If the flex container is single-line and has a definite cross size, the cross size
		//    of the flex line is the flex container’s inner cross size. Otherwise, for each flex line:
		//
		//    If the flex container is single-line, then clamp the line’s cross-size to be within
		//    the container’s computed min and max cross sizes. Note that if CSS 2.1’s definition
		//    of min/max-width/height applied more generally, this behavior would fall out automatically.

		if (flexLines.length == 1 && nodeSize.cross(dir).isDefined()) {
			flexLines[0].crossSize = (nodeSize.cross(dir) - paddingBorder.cross(dir)).orElse(0.0);
		} else {
			for (line in flexLines) {
				//    1. Collect all the flex items whose inline-axis is parallel to the main-axis, whose
				//       align-self is baseline, and whose cross-axis margins are both non-auto. Find the
				//       largest of the distances between each item’s baseline and its hypothetical outer
				//       cross-start edge, and the largest of the distances between each item’s baseline
				//       and its hypothetical outer cross-end edge, and sum these two values.

				//    2. Among all the items not collected by the previous step, find the largest
				//       outer hypothetical cross size.

				//    3. The used cross-size of the flex line is the largest of the numbers found in the
				//       previous two steps and zero.

				var maxBaseline = line.items.iterator().map(child -> child.baseline).fold(0.0, (acc, x) -> Math.max(acc, x));
				line.crossSize = line
					.items
					.iterator()
					.map(child -> {
						var childStyle = child.node.style;
						if (childStyle.getAlignSelf(node.style) == Baseline
							&& childStyle.crossMarginStart(dir) != Auto
							&& childStyle.crossMarginEnd(dir) != Auto
							&& childStyle.crossSize(dir) == Auto)
						{
							maxBaseline - child.baseline + child.hypotheticalOuterSize.cross(dir);
						} else {
							child.hypotheticalOuterSize.cross(dir);
						}
					})
					.fold(0.0, (acc, x) -> Math.max(acc, x));
			}
		}

		// 9. Handle 'align-content: stretch'. If the flex container has a definite cross size,
		//    align-content is stretch, and the sum of the flex lines' cross sizes is less than
		//    the flex container’s inner cross size, increase the cross size of each flex line
		//    by equal amounts such that the sum of their cross sizes exactly equals the
		//    flex container’s inner cross size.

		if (node.style.alignContent == Stretch && nodeSize.cross(dir).isDefined()) {
			var totalCross = flexLines.iterator().map(line -> line.crossSize).sum();
			var innerCross = (nodeSize.cross(dir) - paddingBorder.cross(dir)).orElse(0.0);

			if (totalCross < innerCross) {
				var remaining = innerCross - totalCross;
				var addition = remaining / flexLines.length;
				for (line in flexLines) line.crossSize += addition;
			}
		}

		// 10. Collapse visibility:collapse items. If any flex items have visibility: collapse,
		//     note the cross size of the line they’re in as the item’s strut size, and restart
		//     layout from the beginning.
		//
		//     In this second layout round, when collecting items into lines, treat the collapsed
		//     items as having zero main size. For the rest of the algorithm following that step,
		//     ignore the collapsed items entirely (as if they were display:none) except that after
		//     calculating the cross size of the lines, if any line’s cross size is less than the
		//     largest strut size among all the collapsed items in the line, set its cross size to
		//     that strut size.
		//
		//     Skip this step in the second layout round.

		// TODO implement once (if ever) we support visibility:collapse

		// 11. Determine the used cross size of each flex item. If a flex item has align-self: stretch,
		//     its computed cross size property is auto, and neither of its cross-axis margins are auto,
		//     the used outer cross size is the used cross size of its flex line, clamped according to
		//     the item’s used min and max cross sizes. Otherwise, the used cross size is the item’s
		//     hypothetical cross size.
		//
		//     If the flex item has align-self: stretch, redo layout for its contents, treating this
		//     used size as its definite cross size so that percentage-sized children can be resolved.
		//
		//     Note that this step does not affect the main size of the flex item, even if it has an
		//     intrinsic aspect ratio.

		for (line in flexLines) {
			var lineCrossSize = line.crossSize;

			for (child in line.items) {
				var childStyle = child.node.style;
				child.targetSize.setCross(
					dir,
					if (childStyle.getAlignSelf(node.style) == Stretch
						&& childStyle.crossMarginStart(dir) != Auto
						&& childStyle.crossMarginEnd(dir) != Auto
						&& childStyle.crossSize(dir) == Auto)
					{
						(lineCrossSize - child.margin.cross(dir))
							.maybeMax(child.minSize.cross(dir))
							.maybeMin(child.maxSize.cross(dir));
					} else {
						child.hypotheticalInnerSize.cross(dir);
					}
				);

				child.outerTargetSize.setCross(dir, child.targetSize.cross(dir) + child.margin.cross(dir));
			}
		}

		// 9.5. Main-Axis Alignment

		// 12. Distribute any remaining free space. For each flex line:
		//     1. If the remaining free space is positive and at least one main-axis margin on this
		//        line is auto, distribute the free space equally among these margins. Otherwise,
		//        set all auto margins to zero.
		//     2. Align the items along the main-axis per justify-content.

		for (line in flexLines) {
			var usedSpace = line.items.iterator().map(child -> child.outerTargetSize.main(dir)).sum();
			var freeSpace = innerContainerSize.main(dir) - usedSpace;
			var numAutoMargins = 0;

			for (child in line.items) {
				var childStyle = child.node.style;
				if (childStyle.mainMarginStart(dir) == Auto) {
					numAutoMargins += 1;
				}
				if (childStyle.mainMarginEnd(dir) == Auto) {
					numAutoMargins += 1;
				}
			}

			if (freeSpace > 0.0 && numAutoMargins > 0) {
				var margin = freeSpace / numAutoMargins;

				for (child in line.items) {
					var childStyle = child.node.style;
					if (childStyle.mainMarginStart(dir) == Auto) {
						if (isRow) {
							child.margin.start = margin;
						} else {
							child.margin.top = margin;
						}
					}
					if (childStyle.mainMarginEnd(dir) == Auto) {
						if (isRow) {
							child.margin.end = margin;
						} else {
							child.margin.bottom = margin;
						}
					}
				}
			} else {
				var numItems = line.items.length;
				var layoutReverse = dir.isReverse();

				function justifyItem(i:Int, child:FlexItem) {
					var isFirst = i == 0;

					child.offsetMain = switch (node.style.justifyContent) {
						case FlexStart:
							if (layoutReverse && isFirst) {
								freeSpace;
							} else {
								0.0;
							}
						case Center:
							if (isFirst) {
								freeSpace / 2.0;
							} else {
								0.0;
							}
						case FlexEnd:
							if (isFirst && !layoutReverse) {
								freeSpace;
							} else {
								0.0;
							}
						case SpaceBetween:
							if (isFirst) {
								0.0;
							} else {
								freeSpace / (numItems - 1);
							}
						case SpaceAround:
							if (isFirst) {
								(freeSpace / numItems) / 2.0;
							} else {
								freeSpace / numItems;
							}
						case SpaceEvenly:
							freeSpace / (numItems + 1);
					};
				};

				if (layoutReverse) {
					var len = line.items.length;
					var i = len;
					while (i-- > 0) justifyItem(len - i - 1, line.items[i]);
				} else {
					for (i => item in line.items) justifyItem(i, item);
				}
			}
		}

		// 9.6. Cross-Axis Alignment

		// 13. Resolve cross-axis auto margins. If a flex item has auto cross-axis margins:
		//     - If its outer cross size (treating those auto margins as zero) is less than the
		//       cross size of its flex line, distribute the difference in those sizes equally
		//       to the auto margins.
		//     - Otherwise, if the block-start or inline-start margin (whichever is in the cross axis)
		//       is auto, set it to zero. Set the opposite margin so that the outer cross size of the
		//       item equals the cross size of its flex line.

		for (line in flexLines) {
			var lineCrossSize = line.crossSize;
			var maxBaseline = line.items.iterator().map(child -> child.baseline).fold(0.0, (acc, x) -> Math.max(acc, x));

			for (child in line.items) {
				var freeSpace = lineCrossSize - child.outerTargetSize.cross(dir);
				var childStyle = child.node.style;

				if (childStyle.crossMarginStart(dir) == Auto && childStyle.crossMarginEnd(dir) == Auto) {
					if (isRow) {
						child.margin.top = freeSpace / 2.0;
						child.margin.bottom = freeSpace / 2.0;
					} else {
						child.margin.start = freeSpace / 2.0;
						child.margin.end = freeSpace / 2.0;
					}
				} else if (childStyle.crossMarginStart(dir) == Auto) {
					if (isRow) {
						child.margin.top = freeSpace;
					} else {
						child.margin.start = freeSpace;
					}
				} else if (childStyle.crossMarginEnd(dir) == Auto) {
					if (isRow) {
						child.margin.bottom = freeSpace;
					} else {
						child.margin.end = freeSpace;
					}
				} else {
					// 14. Align all flex items along the cross-axis per align-self, if neither of the item’s
					//     cross-axis margins are auto.

					child.offsetCross = switch (childStyle.getAlignSelf(node.style)) {
						case Auto: 0.0; // Should never happen
						case FlexStart:
							if (isWrapReverse) {
								freeSpace;
							} else {
								0.0;
							}
						case FlexEnd: {
							if (isWrapReverse) {
								0.0;
							} else {
								freeSpace;
							}
						}
						case Center: freeSpace / 2.0;
						case Baseline: {
							if (isRow) {
								maxBaseline - child.baseline;
							} else {
								// baseline alignment only makes sense if the direction is row
								// we treat it as flex-start alignment in columns.
								if (isWrapReverse) {
									freeSpace;
								} else {
									0.0;
								}
							}
						}
						case Stretch: {
							if (isWrapReverse) {
								freeSpace;
							} else {
								0.0;
							}
						}
					};
				}
			}
		}

		// 15. Determine the flex container’s used cross size:
		//     - If the cross size property is a definite size, use that, clamped by the used
		//       min and max cross sizes of the flex container.
		//     - Otherwise, use the sum of the flex lines' cross sizes, clamped by the used
		//       min and max cross sizes of the flex container.

		var totalCrossSize = flexLines.iterator().map(line -> line.crossSize).sum();
		containerSize.setCross(dir, nodeSize.cross(dir).orElse(totalCrossSize + paddingBorder.cross(dir)));
		innerContainerSize.setCross(dir, containerSize.cross(dir) - paddingBorder.cross(dir));

		// We have the container size. If our caller does not care about performing
		// layout we are done now.
		if (!performLayout) {
			var result = new ComputeResult(containerSize);
			node.layoutCache = {
				nodeSize: nodeSize,
				parentSize: parentSize,
				performLayout: performLayout,
				result: result.clone(),
			};
			return result;
		}

		// 16. Align all flex lines per align-content.

		var freeSpace = innerContainerSize.cross(dir) - totalCrossSize;
		var numLines = flexLines.length;

		function alignLine(i:Int, line:FlexLine) {
			var isFirst = i == 0;

			line.offsetCross = switch (node.style.alignContent) {
				case FlexStart:
					if (isFirst && isWrapReverse) {
						freeSpace;
					} else {
						0.0;
					}
				case FlexEnd:
					if (isFirst && !isWrapReverse) {
						freeSpace;
					} else {
						0.0;
					}
				case Center:
					if (isFirst) {
						freeSpace / 2.0;
					} else {
						0.0;
					}
				case Stretch: 0.0;
				case SpaceBetween:
					if (isFirst) {
						0.0;
					} else {
						freeSpace / (numLines - 1);
					}
				case SpaceAround:
					if (isFirst) {
						(freeSpace / numLines) / 2.0;
					} else {
						freeSpace / numLines;
					}
			};
		}

		if (isWrapReverse) {
			var len = flexLines.length;
			var i = len;
			while (i-- > 0) alignLine(len - i - 1, flexLines[i]);
		} else {
			for (i => line in flexLines) alignLine(i, line);
		}

		// Do a final layout pass and gather the resulting layouts
		{
			var totalOffsetCross = paddingBorder.crossStart(dir);

			function layoutLine(line:FlexLine) {
				var totalOffsetMain = paddingBorder.mainStart(dir);
				var lineOffsetCross = line.offsetCross;

				function layoutItem(child:FlexItem) {
					var result = computeInternal(
						child.node,
						child.targetSize.map(s -> s.into()),
						containerSize.map(s -> s.into()),
						true
					);

					var offsetMain = totalOffsetMain
						+ child.offsetMain
						+ child.margin.mainStart(dir)
						+ (child.position.mainStart(dir).orElse(0.0) - child.position.mainEnd(dir).orElse(0.0));

					var offsetCross = totalOffsetCross
						+ child.offsetCross
						+ lineOffsetCross
						+ child.margin.crossStart(dir)
						+ (child.position.crossStart(dir).orElse(0.0) - child.position.crossEnd(dir).orElse(0.0));

					child.node.layout = {
						order: node.children.iterator().position(n -> n == child.node),
						size: result.size,
						location: new Point(
							if (isRow) offsetMain else offsetCross,
							if (isColumn) offsetMain else offsetCross
						),
					};

					totalOffsetMain += child.offsetMain + child.margin.main(dir) + result.size.main(dir);
				};

				if (dir.isReverse()) {
					var i = line.items.length;
					while (i-- > 0) layoutItem(line.items[i]);
				} else {
					for (item in line.items) layoutItem(item);
				}

				totalOffsetCross += lineOffsetCross + line.crossSize;
			};

			if (isWrapReverse) {
				var i = flexLines.length;
				while (i-- > 0) layoutLine(flexLines[i]);
			} else {
				for (line in flexLines) layoutLine(line);
			}
		}

		// Before returning we perform absolute layout on all absolutely positioned children
		{
			for (order => child in node.children) {
				if (child.style.positionType != Absolute) {
					continue;
				}

				var containerWidth = containerSize.width.into();
				var containerHeight = containerSize.height.into();

				var childStyle = child.style;

				var start = childStyle.position.start.resolve(containerWidth)
					+ childStyle.margin.start.resolve(containerWidth);
				var end =
					childStyle.position.end.resolve(containerWidth) + childStyle.margin.end.resolve(containerWidth);
				var top = childStyle.position.top.resolve(containerHeight)
					+ childStyle.margin.top.resolve(containerHeight);
				var bottom = childStyle.position.bottom.resolve(containerHeight)
					+ childStyle.margin.bottom.resolve(containerHeight);

				var startMain, endMain, startCross, endCross;
				if (isRow) {
					startMain = start;
					endMain = end;
					startCross = top;
					endCross = bottom;
				} else {
					startMain = top;
					endMain = bottom;
					startCross = start;
					endCross = end;
				}

				var width = childStyle
					.size
					.width
					.resolve(containerWidth)
					.maybeMax(childStyle.minSize.width.resolve(containerWidth))
					.maybeMin(childStyle.maxSize.width.resolve(containerWidth))
					.orElse(if (start.isDefined() && end.isDefined()) {
						containerWidth - start - end;
					} else {
						Number.undefined();
					});

				var height = childStyle
					.size
					.height
					.resolve(containerHeight)
					.maybeMax(childStyle.minSize.height.resolve(containerHeight))
					.maybeMin(childStyle.maxSize.height.resolve(containerHeight))
					.orElse(if (top.isDefined() && bottom.isDefined()) {
						containerHeight - top - bottom;
					} else {
						Number.undefined();
					});

				var result = computeInternal(
					child,
					{ width: width, height: height },
					{ width: containerWidth, height: containerHeight },
					true
				);

				var freeMainSpace = containerSize.main(dir)
					- result
						.size
						.main(dir)
						.maybeMax(childStyle.minMainSize(dir).resolve(nodeInnerSize.main(dir)))
						.maybeMin(childStyle.maxMainSize(dir).resolve(nodeInnerSize.main(dir)));

				var freeCrossSpace = containerSize.cross(dir)
					- result
						.size
						.cross(dir)
						.maybeMax(childStyle.minCrossSize(dir).resolve(nodeInnerSize.cross(dir)))
						.maybeMin(childStyle.maxCrossSize(dir).resolve(nodeInnerSize.cross(dir)));

				var offsetMain = if (startMain.isDefined()) {
					startMain.orElse(0.0) + border.mainStart(dir);
				} else if (endMain.isDefined()) {
					freeMainSpace - endMain.orElse(0.0) - border.mainEnd(dir);
				} else {
					switch (node.style.justifyContent) {
						case SpaceBetween | FlexStart: paddingBorder.mainStart(dir);
						case FlexEnd: freeMainSpace - paddingBorder.mainEnd(dir);
						case SpaceEvenly | SpaceAround | Center: freeMainSpace / 2.0;
					}
				};

				var offsetCross = if (startCross.isDefined()) {
					startCross.orElse(0.0) + border.crossStart(dir);
				} else if (endCross.isDefined()) {
					freeCrossSpace - endCross.orElse(0.0) - border.crossEnd(dir);
				} else {
					switch (childStyle.getAlignSelf(node.style)) {
						case Auto: 0.0; // Should never happen
						case FlexStart:
							if (isWrapReverse) {
								freeCrossSpace - paddingBorder.crossEnd(dir);
							} else {
								paddingBorder.crossStart(dir);
							}
						case FlexEnd:
							if (isWrapReverse) {
								paddingBorder.crossStart(dir);
							} else {
								freeCrossSpace - paddingBorder.crossEnd(dir);
							}
						case Center: freeCrossSpace / 2.0;
						case Baseline: freeCrossSpace / 2.0; // Treat as center for now until we have baseline support
						case Stretch:
							if (isWrapReverse) {
								freeCrossSpace - paddingBorder.crossEnd(dir);
							} else {
								paddingBorder.crossStart(dir);
							}
					}
				};

				child.layout = {
					order: order,
					size: result.size,
					location: new Point(
						if (isRow) offsetMain else offsetCross,
						if (isColumn) offsetMain else offsetCross
					),
				};
			}
		}

		function hiddenLayout(node:Node, order:Int) {
			node.layout = { order: order, size: Size.zero(), location: Point.zero() };

			for (order => child in node.children) {
				hiddenLayout(child, order);
			}
		}

		for (order => child in node.children) {
			if (child.style.display == None) {
				hiddenLayout(child, order);
			}
		}

		var result = new ComputeResult(containerSize);
		node.layoutCache = {
			nodeSize: nodeSize,
			parentSize: parentSize,
			performLayout: performLayout,
			result: result.clone()
		};

		return result;
	}
}

private typedef FlexItem = {
	var node:Node;

    var size: Size<Number>;
    var minSize: Size<Number>;
    var maxSize: Size<Number>;

    var position: Rect<Number>;
    var margin: Rect<Float>;
    var padding: Rect<Float>;
    var border: Rect<Float>;

    var flexBasis: Float;
    var innerFlexBasis: Float;
    var violation: Float;
    var frozen: Bool;

    var hypotheticalInnerSize: Size<Float>;
    var hypotheticalOuterSize: Size<Float>;
    var targetSize: Size<Float>;
    var outerTargetSize: Size<Float>;

    var baseline: Float;

    // temporary values for holding offset in the main / cross direction.
    // offset is the relative position from the item's natural flow position based on
    // relative position values, alignment, and justification. Does not include margin/padding/border.
    var offsetMain: Float;
    var offsetCross: Float;
}

private typedef FlexLine = {
    var items:Array<FlexItem>;
    var crossSize:Float;
    var offsetCross:Float;
}
