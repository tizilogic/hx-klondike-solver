package solver;

@:enum
abstract CardRank (Int) to Int {
    var EMPTY = 0;
	var ACE = 1;
	var TWO = 2;
	var THREE = 3;
	var FOUR = 4;
	var FIVE = 5;
	var SIX = 6;
	var SEVEN = 7;
	var EIGHT = 8;
	var NINE = 9;
	var TEN = 10;
	var JACK = 11;
	var QUEEN = 12;
	var KING = 13;
}


@:enum
abstract Suit (Int) to Int {
	var CLUBS = 0;
	var DIAMONDS = 1;
	var SPADES = 2;
	var HEARTS = 3;
	var NONE = 255;
}


class Card {
    public var rank:CardRank = EMPTY;
	public var suit:Suits = NONE;
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
        suit = value / 13;
        isRed = suit & 1;
        isOdd = rank & 1;
        foundation = suit + 9;
    }
}
