package stretch;

typedef Layout = {
	var order:Int;
	var size:Size<Float>;
	var location:Point;
}

typedef Cache = {
    var nodeSize:Size<Number>;
    var parentSize:Size<Number>;
    var performLayout:Bool;
    var result:ComputeResult;
}

abstract ComputeResult(Size<Float>) {
    public var size(get,never):Size<Float>;
    inline function get_size() return this;

    public inline function new(size:Size<Float>) {
        this = size;
    }

    public inline function clone():ComputeResult {
        return new ComputeResult({width: this.width, height: this.height});
    }
}
