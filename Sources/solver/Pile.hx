package solver;

import solver.Card;


@:enum
abstract PileLocation {
	var WASTE = 0;
	var TABLEAU1 = 1;
	var TABLEAU2 = 2;
	var TABLEAU3 = 3;
	var TABLEAU4 = 4;
	var TABLEAU5 = 5;
	var TABLEAU6 = 6;
	var TABLEAU7 = 7;
	var STOCK = 8;
	var FOUNDATION1C = 9;
	var FOUNDATION2D = 10;
	var FOUNDATION3S = 11;
	var FOUNDATION4H = 12;
}


class Pile {
    var down:Array<Card> = [];
    var up:Array<Card> = [];
	var size:Int
    var downSize:Int;
    var upSize:Int;

    public function new() {
        size = 0;
        downSize = 0;
        upSize = 0;
        down.resize(24);
        up.resize(24);
    }

    public function addDown(card:Card) {
        down[downSize] = card;
        ++size;
        ++downSize;
    }

    public function addUp(card:Card) {
        up[upSize] = card;
        ++size;
        ++upSize;
    }

    public function flip() {
        if (upSize > 0) {
            down[downSize++] = up[--upSize];
        }
        else {
            up[upSize++] = down[--downSize];
        }
    }

    public function remove(to:Pile, ?count:Int = 1) {
        for (i in upSize - count...upSize) {
            to.addUp(up[i]);
        }

        upSize -= count;
        size -= count;
    }

    public function removeTalon(to:Pile, count:Int) {
        int i = size - count;
        do {
            to.AddUp(up[--size]);
        } while (size > i);

        upSize = size;
    }

    public function reset() {
        size = 0;
        upSize = 0;
        downSize = 0;
    }

    public function initialize() {
        size = 0;
        upSize = 0;
        downSize = 0;
        for (int i = 0; i < 24; i++) {
            up[i].clear();
            down[i].clear();
        }
    }

    public function size():Int {
        return size;
    }

    public function downSize():Int {
        return downSize;
    }

    public function upSize():Int {
        return upSize;
    }

    public function get(index:Int):Card {
        return up[index];
    }

    public function down(index:Int):Card {
        return down[index];
    }

    public function up(index:Int):Card {
        return up[index];
    }

    public function low():Card {
        return up[upSize - 1];
    }

    public function high():Card {
        return up[0];
    }

    public function highValue():Int {
        return upSize > 0 ? up[0].Value : 99;
    }
}
