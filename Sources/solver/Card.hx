package solver;

inline var EMPTY = 0;
inline var ACE = 1;
inline var TWO = 2;
inline var THREE = 3;
inline var FOUR = 4;
inline var FIVE = 5;
inline var SIX = 6;
inline var SEVEN = 7;
inline var EIGHT = 8;
inline var NINE = 9;
inline var TEN = 10;
inline var JACK = 11;
inline var QUEEN = 12;
inline var KING = 13;


inline var CLUBS = 0;
inline var DIAMONDS = 1;
inline var SPADES = 2;
inline var HEARTS = 3;
inline var NONE = 255;


class Card {
    public var rank:Int = EMPTY;
	public var suit:Int = NONE;
    public var isOdd:Int;
    public var isRed:Int;
    public var foundation:Int;
    public var value:Int;

    public function new() {

    }

	public function clear() {
        rank = EMPTY;
        suit = NONE;
    }

	public function set(value:Int) {
        this.value = value;
        rank = (value % 13) + 1;
        suit = Std.int(value / 13);
        isRed = suit & 1;
        isOdd = rank & 1;
        foundation = suit + 9;
    }
}
