package stretch;

inline function into(self:Float):Number {
    return Number.defined(self);
}

extern inline overload function maybeMin(self:Float, rhs:Number):Float {
    return
        if (rhs.isDefined()) Math.min(self, rhs.getDefined())
        else self;
}

extern inline overload function maybeMax(self:Float, rhs:Number):Float {
    return
        if (rhs.isDefined()) Math.max(self, rhs.getDefined())
        else self;
}

extern inline overload function maybeMin(self:Number, rhs:Number):Number {
    return switch [self.isDefined(), rhs.isDefined()] {
        case [true, true]: Number.defined(Math.min(self.getDefined(), rhs.getDefined()));
        case [true, _]: self;
        case _: Number.undefined();
    }
}

extern inline overload function maybeMax(self:Number, rhs:Number):Number {
    return switch [self.isDefined(), rhs.isDefined()] {
        case [true, true]: Number.defined(Math.max(self.getDefined(), rhs.getDefined()));
        case [true, _]: self;
        case _: Number.undefined();
    }
}
