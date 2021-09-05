package solver;


class Random {
	var value:Int;
    var mix:Int;
    var twist:Int;
	var seed:Int;

	inline function calculateNext() {
        var y:Int = value ^ twist - mix ^ value;
        y ^= twist ^ value ^ mix;
        mix ^= twist ^ value;
        value ^= twist - mix;
        twist ^= value ^ y;
        value ^= (twist << 7) ^ (mix >> 16) ^ (y << 8);
    }

    public function new(?seed:Int = 101) {
        setSeed(seed);
    }

    public function setSeed(seed:Int) {
        this.seed = seed;
        mix = 51651237;
        twist = 895213268;
        value = seed;

        for (_ in 0...50) {
            calculateNext();
        }

        seed ^= (seed >> 15);
        value = 0x9417B3AF ^ seed;

        for (_ in 0...950) {
            calculateNext();
        }
    }

    public function next1():Int {
        calculateNext();
        return value & 0x7fffffff;
    }

    public function next2():Int {
        if (seed == 0) { seed = 0x12345987; }
        var k:Int = Std.int(seed / 127773);
        seed = 16807 * (seed - k * 127773) - 2836 * k;
        if (seed < 0) { seed += 2147483647; }
        return seed & 0x7fffffff;
    }
}
