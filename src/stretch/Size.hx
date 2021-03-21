package stretch;

import stretch.Style.FlexDirection;
import stretch.Style.Dimension;

@:structInit
@:using(stretch.Size.SizeTools)
class Size<T> {
	public var width:T;
	public var height:T;

	public inline function map<R>(f:T->R):Size<R> {
		return {
			width: f(width),
			height: f(height)
		};
	}

    public inline function setMain(direction:FlexDirection, value:T) {
        if (direction.isRow()) {
            width = value;
        } else {
            height = value;
        }
    }

    public inline function setCross(direction:FlexDirection, value:T) {
        if (direction.isRow()) {
            height = value;
        } else {
            width = value;
        }
    }

    public inline function main(direction:FlexDirection):T {
        return if (direction.isRow()) width else height;
    }

	public inline function cross(direction:FlexDirection):T {
        return if (direction.isRow()) height else width;
    }

	public static inline function zero():Size<Float> {
		return {width: 0.0, height: 0.0};
	}

    public static inline function undefined():Size<Number> {
        return {width: Number.undefined(), height: Number.undefined()};
    }

    public static inline function dimensions():Size<Dimension> {
        return {width: Auto, height: Auto};
    }
}

class SizeTools {
	public static inline function resolve(self:Size<Dimension>, parent:Size<Number>):Size<Number> {
		return {
			width: self.width.resolve(parent.width),
			height: self.height.resolve(parent.height),
		};
	}

	public static inline function eq(a:Size<Number>, b:Size<Number>):Bool {
		return a.width == b.width && a.height == b.height;
	}
}
