package stretch;

import stretch.Result;

@:allow(stretch.Stretch)
class Node {
	public var style(default,set):Style;
	public var measure(default,set):Null<MeasureFunc>;
	public var layout(default,null):Layout;
	public var layoutCache(default,null):Null<Cache>;
	public var isDirty(default,null):Bool;

	public var parent(default,null):Null<Node>;
	public var children(default,null):Null<Array<Node>>;

	public function new(style:Style, ?children:Array<Node>) {
		if (children == null) {
			children = [];
		} else {
			for (child in children) child.parent = this;
		}
		this.style = style;
		this.children = children;
		layout = {order: 0, size: Size.zero(), location: Point.zero()};
		isDirty = true;
	}

	public static function leaf(style:Style, measure:MeasureFunc):Node {
		var node = new Node(style);
		node.measure = measure;
		return node;
	}

	public function addChild(node:Node) {
		node.parent = this;
		children.push(node);
		markDirty();
	}

	public function removeChild(node:Node) {
		var index = children.indexOf(node);
		if (index != -1) {
			removeChildAtIndex(index);
		}
	}

	public function removeChildAtIndex(index:Int) {
		var child = children[index];
		children.splice(index, 1);
		child.parent = null;
		markDirty();
	}

	public function replaceChildAtIndex(index:Int, child:Node) {
		var oldChild = children[index];
		oldChild.parent = null;
		child.parent = this;
		children[index] = child;
		markDirty();
	}

	public function setChildren(newChildren:Array<Node>) {
		for (child in children) child.parent = null;
		for (child in newChildren) child.parent = this;
		children = newChildren;
		markDirty();
	}

	public inline function markDirty() {
		markDirtyImpl(this);
	}

	public function computeLayout() {
		Stretch.computeLayout(this, Size.undefined());
		return layout;
	}

	function set_style(style:Style):Style {
		this.style = style;
		markDirty();
		return style;
	}

	function set_measure(measure:Null<MeasureFunc>):Null<MeasureFunc> {
		this.measure = measure;
		markDirty();
		return measure;
	}

	static function markDirtyImpl(node:Node) {
		node.layoutCache = null;
		node.isDirty = true;
		if (node.parent != null) {
			markDirtyImpl(node.parent);
		}
	}
}

typedef MeasureFunc = Size<Number> -> Size<Float>;
