package stretch;

inline function filter<T>(i:Iterator<T>, f:T->Bool):FilterIterator<T> {
	return new FilterIterator(i, f);
}

inline function any<T>(i:Iterator<T>, f:T->Bool):Bool {
	var result = false;
	for (v in i) if (f(v)) { result = true; break; }
	return result;
}

inline function position<T>(i:Iterator<T>, f:T->Bool):Int {
	var result = -1;
	var pos = 0;
	for (v in i) {
		if (f(v)) {
			result = pos;
			break;
		}
		pos++;
	}
	return result;
}

inline function all<T>(i:Iterator<T>, f:T->Bool):Bool {
	var result = true;
	for (v in i) if (!f(v)) { result = false; break; }
	return result;
}

inline function fold<T,S>(i:Iterator<T>, initial:S, f:(S,T)->S):S {
	for (item in i) {
		initial = f(initial, item);
	}
	return initial;
}

// TODO: this allocates, report to HF
inline function find<T>(i:Iterator<T>, f:T->Bool):Null<T> {
	var result:Null<T> = null;
	for (v in i) if (f(v)) { result = v; break; }
	return result;
}

inline function map<T,S>(i:Iterator<T>, f:T->S):MapIterator<T,S> {
	return new MapIterator(i, f);
}

inline function collect<T>(i:Iterator<T>):Array<T> {
	return [for (v in i) v];
}

inline function count<T>(i:Iterator<T>):Int {
	var sum = 0;
	for (_ in i) sum++;
	return sum;
}

inline function sum(i:Iterator<Float>):Float {
	var sum = 0.0;
	for (v in i) sum += v;
	return sum;
}

private class MapIterator<T,S> {
	final i:Iterator<T>;
	final f:T->S;

	public inline function new(i:Iterator<T>, f:T->S) {
		this.i = i;
		this.f = f;
	}

	public inline function hasNext():Bool {
		return i.hasNext();
	}

	public inline function next():S {
		return f(i.next());
	}
}

private class FilterIterator<T> {
	final i:Iterator<T>;
	final f:T->Bool;

	public inline function new(i:Iterator<T>, f:T->Bool) {
		this.i = i;
		this.f = f;
		last = cast null;
		hadLast = false;
	}

	var last:T;
	var hadLast:Bool;

	public inline function hasNext():Bool {
		var hasNext = i.hasNext();
		while (hasNext) {
			var last = i.next();
			if (f(last)) {
				this.last = last;
				break;
			} else {
				hasNext = i.hasNext();
			}
		}
		return hasNext;
	}

	public inline function next():T {
		return last;
	}
}
