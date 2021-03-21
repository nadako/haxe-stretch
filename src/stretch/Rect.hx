package stretch;

import stretch.Style.Dimension;
import stretch.Style.FlexDirection;

@:structInit
@:using(stretch.Rect.RectTools)
class Rect<T> {
	public var start:T;
	public var end:T;
	public var top:T;
	public var bottom:T;

    public inline function map<R>(f:T->R):Rect<R> {
		return {
			start: f(start),
			end: f(end),
			top: f(top),
			bottom: f(bottom),
		};
	}

    public inline function mainStart(direction:FlexDirection):T {
        return if (direction.isRow()) start else top;
    }

    public inline function mainEnd(direction:FlexDirection):T {
        return if (direction.isRow()) end else bottom;
    }

    public inline function crossStart(direction:FlexDirection):T {
        return if (direction.isRow()) top else start;
    }

    public inline function crossEnd(direction:FlexDirection):T {
        return if (direction.isRow()) bottom else end;
    }

    public static inline function dimensions():Rect<Dimension> {
        return {
            start: Undefined,
            end: Undefined,
            top: Undefined,
            bottom: Undefined,
        };
    }
}

class RectTools {
    public static inline function horizontal(self:Rect<Float>):Float {
        return self.start + self.end;
    }

    public static inline function vertical(self:Rect<Float>):Float {
        return self.top + self.bottom;
    }

    public static inline function main(self:Rect<Float>, direction:FlexDirection):Float {
        return if (direction.isRow()) self.horizontal() else self.vertical();
    }

    public static inline function cross(self:Rect<Float>, direction:FlexDirection):Float {
        return if (direction.isRow()) self.vertical() else self.horizontal();
    }
}
