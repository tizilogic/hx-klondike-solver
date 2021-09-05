package solver;

import solver.Card;


inline var WASTE = 0;
inline var TABLEAU1 = 1;
inline var TABLEAU2 = 2;
inline var TABLEAU3 = 3;
inline var TABLEAU4 = 4;
inline var TABLEAU5 = 5;
inline var TABLEAU6 = 6;
inline var TABLEAU7 = 7;
inline var STOCK = 8;
inline var FOUNDATION1C = 9;
inline var FOUNDATION2D = 10;
inline var FOUNDATION3S = 11;
inline var FOUNDATION4H = 12;


class Pile {
    var mDown:Array<Card>;
    var mUp:Array<Card>;
	var mSize:Int;
    var mDownSize:Int;
    var mUpSize:Int;

    public function new() {
        mSize = 0;
        mDownSize = 0;
        mUpSize = 0;
        mDown = [for (_ in 0...24) new Card()];
        mUp = [for (_ in 0...24) new Card()];
    }

    public function addDown(card:Card) {
        mDown[mDownSize++] = card;
        ++mSize;
    }

    public function addUp(card:Card) {
        mUp[mUpSize++] = card;
        ++mSize;
    }

    public function flip() {
        if (mUpSize > 0) {
            mDown[mDownSize++] = mUp[--mUpSize];
        }
        else {
            mUp[mUpSize++] = mDown[--mDownSize];
        }
    }

    public function remove(to:Pile, ?count:Int = 1) {
        for (i in mUpSize - count...mUpSize) {
            to.addUp(mUp[i]);
        }

        mUpSize -= count;
        mSize -= count;
    }

    public function removeTalon(to:Pile, count:Int) {
        var i:Int = mSize - count;
        do {
            to.addUp(mUp[--mSize]);
        } while (mSize > i);

        mUpSize = mSize;
    }

    public function reset() {
        mSize = 0;
        mUpSize = 0;
        mDownSize = 0;
    }

    public function initialize() {
        mSize = 0;
        mUpSize = 0;
        mDownSize = 0;
        for (i in 0...24) {
            mUp[i].clear();
            mDown[i].clear();
        }
    }

    public function size():Int {
        return mSize;
    }

    public function downSize():Int {
        return mDownSize;
    }

    public function upSize():Int {
        return mUpSize;
    }

    public function get(index:Int):Card {
        return mUp[index];
    }

    public function down(index:Int):Card {
        return mDown[index];
    }

    public function up(index:Int):Card {
        return mUp[index];
    }

    public function low():Card {
        return mUp[mUpSize - 1];
    }

    public function high():Card {
        return mUp[0];
    }

    public function highValue():Int {
        return mUpSize > 0 ? mUp[0].value : 99;
    }
}
