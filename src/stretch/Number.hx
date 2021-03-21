package stretch;

abstract Number(Null<Float>) {
	public inline static function defined(value:Float):Number {
		return cast value;
	}

	public inline static function undefined():Number {
		return null;
	}

    @:op(a + b) inline function addNumber(rhs:Number):Number {
        return switch [isDefined(), rhs.isDefined()] {
            case [true, true]: Number.defined(getDefined() + rhs.getDefined());
            case [true, _]: cast this;
            case _: Number.undefined();
        }
    }

	@:op(a - b) inline function subNumber(rhs:Number):Number {
        return switch [isDefined(), rhs.isDefined()] {
            case [true, true]: Number.defined(getDefined() - rhs.getDefined());
            case [true, _]: cast this;
            case _: Number.undefined();
        }
    }

	@:op(a * b) inline function mulFloat(rhs:Float):Number {
		return
			if (isDefined()) defined(this * rhs);
			else undefined();
	}

	@:op(a - b) inline function subFloat(rhs:Float):Number {
		return
			if (isDefined()) defined(this - rhs)
			else undefined();
    }

	public inline function isDefined():Bool {
		return this != null;
	}

	public inline function isUndefined():Bool {
		return this == null;
	}

	public inline function getDefined():Float {
		return this;
	}

    public overload extern inline function orElse(other:Float):Float {
        return if (isDefined()) getDefined() else other;
    }

    public overload extern inline function orElse(other:Number):Number {
        return if (isDefined()) cast this else other;
    }
}
