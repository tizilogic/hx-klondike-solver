package solver;

inline var KEYSIZE = 21;
inline var KEYSIZEM1 = KEYSIZE - 1;


class HashKey {
	public var key:Array<Int>;

	public function new() {
        key = [for (i in 0...KEYSIZE) 0];
	}

	public function computeHash():Int {
		var hash:Int = 0;
		var i:Int = 0;

		while (i < KEYSIZE) {
			hash = key[i++] + (hash << 7) + (hash << 16) - hash;
		}

		return hash;
	}

	public function eq(other:Hash):Bool {
		int i = 0;
		while (i < KEYSIZEM1 && key[i] == other.key[i]) { i++; }
		return key[i] == other.key[i];
	}

	public function get(index:Int):Int {
		return key[index];
	}
}

@:generic
class KeyValue<T> {
    public var next:KeyValue<T>;
	public var key:HashKey;
	public var value:T;
	public var hash:Int;

    public function new(?hash:Null<Int> = null, ?key:HashKey, ?value:Null<T> = null, ?next:KeyValue<T> = null) {
        if (hash == null) {
            next = null
        }
        else {
            this.next = next;
            this.key = key;
            this.hash = hash;
            this.value = value;
        }
    }
}

@:generic
class HashMap<T> {
    var table:Array<KeyValue<T>>;
	var mSize:Int;
    var mCapacity:Int;
    var powerOf2:Int;
    var mMaxLength:Int;
    var mSlotsUsed:Int;

    public var size(get, null):Int;
    public var capacity(get, null):Int;
    public var slotsUsed(get, null):Int;
    public var maxLength(get, null):Int;

    public function new(powerOf2:Int) {
        this.powerOf2 = powerOf2;
        mSize = 0;
        mSlotsUsed = 0;
        mMaxLength = 0;
        mCapacity = (1 << powerOf2) - 1;
        table = [for (_ in 0...mCapacity + 1) null];
    }

	inline function get_size():Int {
        return mSize;
    }

	inline function get_capacity():Int {
        return mCapacity + 1;
    }

	inline function get_slotsUsed():Int {
        return mSlotsUsed;
    }

	inline function get_maxLength():Int {
        return mMaxLength;
    }

	public function clear() {
        table = [for (_ in 0...mCapacity + 1) null];
        mSize = 0;
        mSlotsUsed = 0;
        mMaxLength = 0;
    }

	public function add(key:HashKey, value:T):KeyValue<T> {
        var hash:Int = key.computeHash();
        var i:Int = hash;
        i ^= (hash >> 16);
        i &= capacity;
        node:KeyValue<T> = table[i];

        int length = 1;
        while (node != null && node.key[0] != 0) {
            if (node.hash == hash && key == node.key) { return node; }
            node = node.next;
            ++length;
        }

        ++size;
        node = table[i];
        if (node.key[0] != 0) {
            node.next = new KeyValue<T>(node.hash, node.key, node.value, node.next);
        }
        node.hash = hash;
        node.key = key;
        node.value = value;

        if (length > mMaxLength) { mMaxLength = length; }
        if (length == 1) { mSlotsUsed++; }
        return null;
    }
}
