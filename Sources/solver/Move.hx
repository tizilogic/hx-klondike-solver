package solver;

typedef MoveArgs = {from:Int, to:Int, count:Int, extra:Int};

class MoveNode {
	public var parent:MoveNode;
	public var value:Move;

    public function new(move:Move, ?parent:MoveNode = null) {
        this.value = move;
        this.parent = parent;
    }
}


class Move {
	public var from:Int;
    public var to:Int;
    public var count:Int;
    public var extra:Int;

    public function new(?moveArgs:MoveArgs = null) {
        if (moveArgs != null) {
            set(moveArgs);
        }
    }

    public inline function set(moveArgs:MoveArgs) {
        this.from = moveArgs.from;
        this.to = moveArgs.to;
        this.count = moveArgs.count;
        this.extra = moveArgs.extra;
    }
}
