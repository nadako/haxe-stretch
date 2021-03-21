package stretch;

class Point {
	public var x:Float;
	public var y:Float;

	public inline function new(x:Float, y:Float) {
		this.x = x;
		this.y = y;
	}

	public static inline function zero():Point {
		return new Point(0.0, 0.0);
	}
}
