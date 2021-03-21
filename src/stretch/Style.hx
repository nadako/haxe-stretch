package stretch;

enum AlignItems {
    FlexStart;
    FlexEnd;
    Center;
    Baseline;
    Stretch;
}

enum AlignSelf {
    Auto;
    FlexStart;
    FlexEnd;
    Center;
    Baseline;
    Stretch;
}

enum AlignContent {
    FlexStart;
    FlexEnd;
    Center;
    Stretch;
    SpaceBetween;
    SpaceAround;
}

enum Direction {
	Inherit;
	LTR;
	RTL;
}

enum Display {
	Flex;
	None;
}

@:using(Style.FlexDirectionTools)
enum FlexDirection {
    Row;
    Column;
    RowReverse;
    ColumnReverse;
}

class FlexDirectionTools {
    public static inline function isRow(self:FlexDirection):Bool {
        return switch (self) {
            case Row | RowReverse: true;
            case _: false;
        }
    }

    public static inline function isColumn(self:FlexDirection):Bool {
        return switch (self) {
            case Column | ColumnReverse: true;
            case _: false;
        }
    }

	public static inline function isReverse(self:FlexDirection):Bool {
        return switch (self) {
            case RowReverse | ColumnReverse: true;
            case _: false;
        }
    }
}

enum JustifyContent {
    FlexStart;
    FlexEnd;
    Center;
    SpaceBetween;
    SpaceAround;
    SpaceEvenly;
}

enum Overflow {
    Visible;
    Hidden;
    Scroll;
}

enum PositionType {
	Relative;
	Absolute;
}

enum FlexWrap {
    NoWrap;
    Wrap;
    WrapReverse;
}

@:using(Style.DimensionTools)
enum Dimension {
    Undefined;
    Auto;
    Points(points:Float);
    Percent(percent:Float);
}

class DimensionTools {
	public static inline function resolve(self:Dimension, parentDim:Number):Number {
		return switch (self) {
			case Points(points): Number.defined(points);
			case Percent(percent): parentDim * percent;
			case _: Number.undefined();
		}
	}

	public static inline function isDefined(self:Dimension):Bool {
		return switch (self) {
			case Points(_) | Percent(_): true;
			case _: false;
		}
	}
}

@:structInit
class Style {
	public var display:Display = Flex;
	public var positionType:PositionType = Relative;
	public var direction:Direction = Inherit;
	public var flexDirection:FlexDirection = Row;
	public var flexWrap:FlexWrap = NoWrap;
	public var overflow:Overflow = Visible;
	public var alignItems:AlignItems = Stretch;
	public var alignSelf:AlignSelf = Auto;
	public var alignContent:AlignContent = Stretch;
	public var justifyContent:JustifyContent = FlexStart;
	public var position:Rect<Dimension> = Rect.dimensions();
	public var margin:Rect<Dimension> = Rect.dimensions();
	public var padding:Rect<Dimension> = Rect.dimensions();
	public var border:Rect<Dimension> = Rect.dimensions();
	public var flexGrow:Float = 0.0;
	public var flexShrink:Float = 1.0;
	public var flexBasis:Dimension = Auto;
	public var size:Size<Dimension> = Size.dimensions();
	public var minSize:Size<Dimension> = Size.dimensions();
	public var maxSize:Size<Dimension> = Size.dimensions();
	public var aspectRatio:Number = Number.undefined();

	public inline function minMainSize(direction:FlexDirection):Dimension {
		return if (direction.isRow()) minSize.width else minSize.height;
	}

	public inline function maxMainSize(direction:FlexDirection):Dimension {
		return if (direction.isRow()) maxSize.width else maxSize.height;
	}

	public inline function mainMarginStart(direction:FlexDirection):Dimension {
		return if (direction.isRow()) margin.start else margin.top;
	}

	public inline function mainMarginEnd(direction:FlexDirection):Dimension {
		return if (direction.isRow()) margin.end else margin.bottom;
	}

	public inline function crossSize(direction:FlexDirection):Dimension {
		return if (direction.isRow()) size.height else size.width;
	}

    public inline function minCrossSize(direction:FlexDirection): Dimension {
        return if (direction.isRow()) minSize.height else minSize.width;
    }

    public inline function maxCrossSize(direction:FlexDirection): Dimension {
        return if (direction.isRow()) maxSize.height else maxSize.width;
    }

    public inline function crossMarginStart(direction:FlexDirection):Dimension {
        return if (direction.isRow()) margin.top else margin.start;
    }

    public inline function crossMarginEnd(direction:FlexDirection):Dimension {
        return if (direction.isRow()) margin.bottom else margin.end;
    }

	public function getAlignSelf(parent:Style):AlignSelf {
        return if (alignSelf == Auto) {
            switch (parent.alignItems) {
                case FlexStart: FlexStart;
                case FlexEnd: FlexEnd;
                case Center: Center;
                case Baseline: Baseline;
                case Stretch: Stretch;
            }
        } else {
            alignSelf;
        }
	}
}
