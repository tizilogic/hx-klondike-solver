package solver;

import solver.Pile;
import solver.Card;
import solver.Move;
import solver.Random;
import solver.HashMap;

inline var PILES:String = "W1234567GCDSH";
inline var RANKS:String = "0A23456789TJQK";
inline var SUITS:String = "CDSH";


@:enum
abstract SolveResult (Int) to Int {
	var CouldNotComplete = -2;
	var SolvedMayNotBeMinimal = -1;
	var Impossible = 0;
	var SolvedMinimal = 1;
}


class Solitaire {
	var mMovesMade:Array<Move> = [];
	var piles:Array<Pile> = [];
	var cards:Array<Card> = [];
	var mMovesAvailable:Array<Move>;
	var random:Random;
	var mDrawCount:Int;
    var mRoundCount:Int;
    var mFoundationCount:Int;
    var mMovesAvailableCount:Int;
    var mMovesMadeCount:Int;

    public function new() {
        mMovesMade.resize(512);
        piles.resize(13);
        cards.resize(52);
        mMovesAvailable = [for (_ in 0...32) new Move()];
        random = new Random();
        initialize();
    }

	public function initialize() {
        mDrawCount = 1;
        for (i in 0...52) {
            cards[i] = new Card();
            cards[i].set(i);
        }
        for (i in 0...13) {
            piles[i] = new Pile();
            piles[i].initialize();
        }
    }

	function foundationMin():Int {
        var one:Int = piles[FOUNDATION2D].size();
        var two:Int = piles[FOUNDATION4H].size();
        var redfoundationMin:Int = one <= two ? one : two;
        one = piles[FOUNDATION1C].size();
        two = piles[FOUNDATION3S].size();
        var blackfoundationMin:Int = one <= two ? one : two;
        return 2 + (blackfoundationMin <= redfoundationMin ? blackfoundationMin : redfoundationMin);
    }

	function getTalonCards(talon:Array<Card>, talonMoves:Array<Int>) {
        var index:Int = 0;

        //Check waste
        var waste:Pile = piles[WASTE];
        var wasteSize:Int = waste.size();
        if (wasteSize > 0) {
            talon[index] = waste.low();
            talonMoves[index++] = 0;
        }

        //Check cards waiting to be turned over from stock
        var stock:Pile = piles[STOCK];
        var stockSize:Int = stock.size();
        var j:Int = (stockSize > 0 && stockSize - mDrawCount <= 0) ? 0 : stockSize - mDrawCount;
        while (j >= 0) {
            talon[index] = stock.up(j);
            talonMoves[index++] = stockSize - j;

            if (j > 0 && j < mDrawCount) { j = mDrawCount; }
            j -= mDrawCount;
        }

        //Check cards already turned over in the waste, meaning we have to "redeal" the deck to get to it
        var amountToDraw:Int = stockSize;
        amountToDraw += stockSize;
        amountToDraw += wasteSize;
        amountToDraw++;
        wasteSize--;

        var lastIndex:Int = mDrawCount - 1;
        while (lastIndex < wasteSize) {
            talon[index] = waste.up(lastIndex);
            talonMoves[index++] = amountToDraw + lastIndex;
            lastIndex += mDrawCount;
        }

        //Check cards in stock after a "redeal". Only happens when draw count > 1 and you have access to more cards in the talon
        if (lastIndex > wasteSize && wasteSize > -1) {
            amountToDraw += wasteSize;
            amountToDraw += stockSize;
            var j:Int = (stockSize > 0 && stockSize - lastIndex + wasteSize <= 0) ? 0 : stockSize - lastIndex + wasteSize;
            while (j > 0) {
                talon[index] = stock.up(j);
                talonMoves[index++] = amountToDraw - j;
                j -= mDrawCount;
            }
        }

        return index;
    }

    public function solveFast(maxClosedCount:Int, twoShift:Int, threeShift:Int):SolveResult {
        makeAutoMoves();
        if (mMovesAvailableCount == 0) { return mFoundationCount== 52 ? SolvedMinimal : Impossible; }

        var openCount:Int = 1;
        var maxFoundationCount:Int = mFoundationCount;
        var bestSolutionMoveCount:Int = 512;
        var totalOpenCount:Int = 1;

        var powerOf2:Int = 1;
        while (maxClosedCount > (1 << (powerOf2 + 2))) {
            powerOf2++;
        }
        var closed = new HashMap<Int>(powerOf2);
        var open:Array<Array<MoveNode>> = [for (_ in 0...512) []];
        // stack<shared_ptr<MoveNode>> open[512];
        var movesToMake:Array<Move> = [for (_ in 0...512) new Move()];
        var bestSolution:Array<Move> = [for (_ in 0...512) new Move()];
        bestSolution[0].count = 255;
        var startMoves:Int = movesMadeNormalizedCount() + minimumMovesLeft();
        var threeClosed:Int = maxClosedCount >> threeShift;
        var twoClosed:Int = maxClosedCount >> twoShift;
        var firstNode:MoveNode = mMovesMadeCount > 0 ? new MoveNode(mMovesMade[mMovesMadeCount - 1]) : null;
        var node:MoveNode = firstNode;
        var j:Int = mMovesMadeCount - 2;
        while (j >= 0) {
            node.parent = new MoveNode(mMovesMade[j]);
            node = node.parent;
            --j;
        }
        open[startMoves].push(firstNode);
        while (closed.size < maxClosedCount) {
            //Check for lowest score length
            var index:Int = startMoves;
            while (index < 512 && open[index].length == 0) { index++; }

            //End solver if no more states
            if (index >= 512) { break; }

            //Get next state to evaluate
            --openCount;
            firstNode = open[index][open[index].length - 1];
            open[index].pop();

            //Initialize game to the found state
            resetGame(mDrawCount);
            var movesTotal:Int = 0;
            node = firstNode;
            while (node != null) {
                movesToMake[movesTotal++] = node.value;
                node = node.parent;
            }
            while (movesTotal > 0) {
                makeMove(movesToMake[--movesTotal]);
            }

            //Make any auto moves
            updateAvailableMoves();
            while (mMovesAvailableCount == 1) {
                var move:Move = mMovesAvailable[0];
                makeMove(move);
                firstNode = new MoveNode(move, firstNode);
                updateAvailableMoves();
            }
            movesTotal = movesMadeNormalizedCount();

            //Check for best solution to foundations
            if (mFoundationCount> maxFoundationCount || (mFoundationCount== maxFoundationCount && bestSolutionMoveCount > movesTotal)) {
                bestSolutionMoveCount = movesTotal;
                maxFoundationCount = mFoundationCount;

                //Save solution
                for (i in 0...mMovesMadeCount) {
                    bestSolution[i] = mMovesMade[i].copy();
                }
                bestSolution[mMovesMadeCount].count = 255;
            } else if (maxFoundationCount == 52) {
                //Dont check state if above or equal to current best solution
                var helper:Int = minimumMovesLeft();
                helper += movesTotal;
                if (helper >= bestSolutionMoveCount) { continue; }
            }

            //Make available moves and add them to be evaulated
            var bestMove1:Move = new Move();
            var bestMove2:Move = new Move();
            var bestMove3:Move = new Move();
            var bestMoveAdded1:Int = 512;
            var bestMoveHelper1:Int = 512;
            var bestMoveAdded2:Int = 512;
            var bestMoveHelper2:Int = 512;
            var bestMoveAdded3:Int = 512;
            var bestMoveHelper3:Int = 512;
            for (i in 0...mMovesAvailableCount) {
                var move:Move = mMovesAvailable[i];
                var movesAdded:Int = movesAdded(move);

                makeMove(move);

                movesAdded += movesTotal;
                movesAdded += minimumMovesLeft();
                if (maxFoundationCount < 52 || movesAdded < bestSolutionMoveCount) {
                    var helper:Int = movesAdded;
                    helper += 52 - mFoundationCount+ mRoundCount ;

                    if (helper < bestMoveHelper1) {
                        if (bestMoveHelper1 <= bestMoveHelper2) {
                            if (bestMoveHelper2 <= bestMoveHelper3) {
                                bestMove3 = bestMove2;
                                bestMoveAdded3 = bestMoveAdded2;
                                bestMoveHelper3 = bestMoveHelper2;
                            }
                            bestMove2 = bestMove1;
                            bestMoveAdded2 = bestMoveAdded1;
                            bestMoveHelper2 = bestMoveHelper1;
                        } else if (bestMoveHelper1 <= bestMoveHelper3) {
                            bestMove3 = bestMove1;
                            bestMoveAdded3 = bestMoveAdded1;
                            bestMoveHelper3 = bestMoveHelper1;
                        }
                        bestMove1 = move;
                        bestMoveAdded1 = movesAdded;
                        bestMoveHelper1 = helper;
                    } else if (helper < bestMoveHelper2) {
                        if (bestMoveHelper2 <= bestMoveHelper3) {
                            bestMove3 = bestMove2;
                            bestMoveAdded3 = bestMoveAdded2;
                            bestMoveHelper3 = bestMoveHelper2;
                        }
                        bestMove2 = move;
                        bestMoveAdded2 = movesAdded;
                        bestMoveHelper2 = helper;
                    } else if (helper < bestMoveHelper3) {
                        bestMove3 = move;
                        bestMoveAdded3 = movesAdded;
                        bestMoveHelper3 = helper;
                    }
                }

                undoMove();
            }

            if (bestMoveHelper1 < 512) {
                makeMove(bestMove1);

                var key:HashKey = gameState();
                var result:KeyValue<Int> = closed.add(key, bestMoveAdded1);
                if (result == null || result.value > bestMoveAdded1) {
                    node = new MoveNode(bestMove1, firstNode);
                    if (result != null) { result.value = bestMoveAdded1; }

                    ++totalOpenCount;
                    ++openCount;
                    open[bestMoveHelper1].push(node);
                }

                undoMove();
            }
            if (closed.size < twoClosed && bestMoveHelper2 < 512) {
                makeMove(bestMove2);

                var key:HashKey = gameState();
                var result:KeyValue<Int> = closed.add(key, bestMoveAdded2);
                if (result == null || result.value > bestMoveAdded2) {
                    node = new MoveNode(bestMove2, firstNode);
                    if (result != null) { result.value = bestMoveAdded2; }

                    ++totalOpenCount;
                    ++openCount;
                    open[bestMoveHelper2].push(node);
                }

                undoMove();
            }
            if (closed.size < threeClosed && bestMoveHelper3 < 512) {
                makeMove(bestMove3);

                var key:HashKey = gameState();
                var result:KeyValue<Int> = closed.add(key, bestMoveAdded3);
                if (result == null || result.value > bestMoveAdded3) {
                    node = new MoveNode(bestMove3, firstNode);
                    if (result != null) { result.value = bestMoveAdded3; }

                    ++totalOpenCount;
                    ++openCount;
                    open[bestMoveHelper3].push(node);
                }

                undoMove();
            }
        }

        //Reset game to best solution found
        resetGame(mDrawCount);
        j = 0;
        while (bestSolution[j].count < 255) {
            makeMove(bestSolution[j]);
            j++;
        }
        return maxFoundationCount == 52 ? SolvedMayNotBeMinimal : CouldNotComplete;
    }

    /*public function solveMinimalMultithreaded(Int numThreads, Int maxClosedCount):SolveResult {
        SolitaireWorker worker(*this, maxClosedCount);
        return worker.Run(numThreads);
    }*/

    public function solveMinimal(maxClosedCount:Int):SolveResult {
        makeAutoMoves();
        if (mMovesAvailableCount == 0) { return mFoundationCount== 52 ? SolvedMinimal : Impossible; }

        var openCount:Int = 1;
        var maxFoundationCount:Int = mFoundationCount;
        var bestSolutionMoveCount:Int = 512;
        var totalOpenCount:Int = 1;

        var powerOf2:Int = 1;
        while (maxClosedCount > (1 << (powerOf2 + 2))) {
            powerOf2++;
        }
        var closed = new HashMap<Int>(powerOf2);
        var open:Array<Array<MoveNode>> = [for (_ in 0...512) []];

        var movesToMake:Array<Move> = [for (_ in 0...512) new Move()];
        var bestSolution:Array<Move> = [for (_ in 0...512) new Move()];
        bestSolution[0].count = 255;
        var startMoves:Int = movesMadeNormalizedCount() + minimumMovesLeft();
        var firstNode:MoveNode = mMovesMadeCount > 0 ? new MoveNode(mMovesMade[mMovesMadeCount - 1]) : null;
        var node:MoveNode = firstNode;
        var j:Int = mMovesMadeCount - 2;
        while (j >= 0) {
            node.parent = new MoveNode(mMovesMade[j]);
            node = node.parent;
            --j;
        }

        open[startMoves].push(firstNode);
        while (closed.size < maxClosedCount) {
            //Check for lowest score length
            var index:Int = startMoves;
            while (index < 512 && open[index].length == 0) { index++; }

            //End solver if no more states
            if (index >= 512) { break; }

            //Get next state to evaluate
            --openCount;
            firstNode = open[index][open[index].length - 1];
            open[index].pop();

            //Initialize game to the found state
            resetGame(mDrawCount);
            var movesTotal:Int = 0;
            node = firstNode;
            while (node != null) {
                movesToMake[movesTotal++] = node.value;
                node = node.parent;
            }
            while (movesTotal > 0) {
                makeMove(movesToMake[--movesTotal]);
            }

            //Make any auto moves
            updateAvailableMoves();
            while (mMovesAvailableCount == 1) {
                var move:Move = mMovesAvailable[0];
                makeMove(move);
                firstNode = new MoveNode(move, firstNode);
                updateAvailableMoves();
            }
            movesTotal = movesMadeNormalizedCount();

            //Check for best solution to foundations
            if (mFoundationCount> maxFoundationCount || (mFoundationCount== maxFoundationCount && bestSolutionMoveCount > movesTotal)) {
                bestSolutionMoveCount = movesTotal;
                maxFoundationCount = mFoundationCount;

                //Save solution
                for (i in 0...mMovesMadeCount) {
                    bestSolution[i] = mMovesMade[i].copy();
                }
                bestSolution[mMovesMadeCount].count = 255;
            } else if (maxFoundationCount == 52) {
                //Dont check state if above or equal to current best solution
                var helper:Int = minimumMovesLeft();
                helper += movesTotal;
                if (helper >= bestSolutionMoveCount) { continue; }
            }

            //Make available moves and add them to be evaulated
            for (i in 0...mMovesAvailableCount) {
                var move:Move = mMovesAvailable[i];
                var movesAdded:Int = movesAdded(move);

                makeMove(move);

                movesAdded += movesTotal;
                movesAdded += minimumMovesLeft();
                if (maxFoundationCount < 52 || movesAdded < bestSolutionMoveCount) {
                    var helper:Int = movesAdded;
                    helper += 52 - mFoundationCount+ mRoundCount ;
                    var key:HashKey = gameState();
                    var result:KeyValue<Int> = closed.add(key, movesAdded);
                    if (result == null || result.value > movesAdded) {
                        node = new MoveNode(move, firstNode);
                        if (result != null) { result.value = movesAdded; }

                        ++totalOpenCount;
                        ++openCount;
                        open[helper].push(node);
                    }
                }

                undoMove();
            }
        }

        //Reset game to best solution found
        resetGame(mDrawCount);
        var i:Int = 0;
        while (bestSolution[i].count < 255) {
            makeMove(bestSolution[i]);
            ++i;
        }
        return closed.size >= maxClosedCount ? (maxFoundationCount == 52 ? SolvedMayNotBeMinimal : CouldNotComplete) : (maxFoundationCount == 52 ? SolvedMinimal : Impossible);
    }

    public function updateAvailableMoves() {
        mMovesAvailableCount = 0;
        var foundationMin:Int = foundationMin();
        var talon:Array<Card> = [for (_ in 0...24) new Card()];
        var talonMoves:Array<Int> = [for (_ in 0...24) 0];
        var talonCount:Int = getTalonCards(talon, talonMoves);

        //Check tableau to foundation, Check tableau to tableau
        for (i in TABLEAU1...TABLEAU7 + 1) {
            var pile1:Pile = piles[i];
            var pile1Size:Int = pile1.size();

            if (pile1Size == 0) { continue; }

            var pile1UpSize:Int = pile1.upSize();
            var card1:Card = pile1.low();
            var cardFoundation:Int = card1.foundation;

            if (card1.rank - piles[cardFoundation].size() == 1) {
                //logic used to tell if we can safely move a card to its foundation
                if (card1.rank < foundationMin) {
                    mMovesAvailable[0].set({from:i, to:cardFoundation, count:1, extra:(pile1UpSize == 1 && pile1Size > 1 ? 1 : 0)});
                    mMovesAvailableCount = 1;
                    return;
                }

                mMovesAvailable[mMovesAvailableCount++].set({from:i, to:cardFoundation, count:1, extra:(pile1UpSize == 1 && pile1Size > 1 ? 1 : 0)});
            }

            var card2:Card = pile1.high();
            var pile1Length:Int = card2.rank - card1.rank + 1;
            var kingMoved:Bool = false;

            for (j in TABLEAU1...TABLEAU7 + 1) {
                if (i == j) { continue; }

                var pile2:Pile = piles[j];

                if (pile2.size() == 0) {
                    if (card2.rank == KING && pile1Size != pile1Length && !kingMoved) {
                        mMovesAvailable[mMovesAvailableCount++].set({from:i, to:j, count:pile1Length, extra:1});
                        //only create one move for a blank spot
                        kingMoved = true;
                    }
                    continue;
                }

                var card3:Card = pile2.low();
                //logic used to determine if a pile of cards can be moved ontop of another pile of cards
                if (card1.rank >= card3.rank || card2.rank + 1 < card3.rank || ((card3.isRed ^ card1.isRed) ^ (card3.isOdd ^ card1.isOdd)) != 0) {
                    continue;
                }

                var pile1Moved:Int = card3.rank - card1.rank;

                if (pile1Moved == pile1Length) {//we are moving all face up cards
                    mMovesAvailable[mMovesAvailableCount++].set({from:i, to:j, count:pile1Moved, extra:pile1Size > pile1Moved ? 1 : 0});
                    continue;
                }

                //look to see if we are covering a card that can be moved to the foundation
                var card4:Card = pile1.get(pile1UpSize - pile1Moved - 1);
                if (card4.rank - piles[card4.foundation].size() == 1) {
                    mMovesAvailable[mMovesAvailableCount++].set({from:i, to:j, count:pile1Moved, extra:0});
                }
            }
        }

        //Check talon cards
        for (j in 0...talonCount) {
            var talonCard:Card = talon[j];
            var foundation:Int = talonCard.foundation;
            var cardsToDraw:Int = talonMoves[j];

            if (talonCard.rank - piles[foundation].size() == 1) {
                if (talonCard.rank <= foundationMin) {
                    if (mDrawCount == 1) {
                        if (cardsToDraw == 0 || mMovesAvailableCount == 0) {
                            mMovesAvailable[0].set({from:WASTE, to:foundation, count:1, extra:cardsToDraw});
                            mMovesAvailableCount = 1;
                            return;
                        } else {
                            mMovesAvailable[mMovesAvailableCount++].set({from:WASTE, to:foundation, count:1, extra:cardsToDraw});
                            break;
                        }
                    } else {
                        mMovesAvailable[mMovesAvailableCount++].set({from:WASTE, to:foundation, count:1, extra:cardsToDraw});
                        continue;
                    }
                }

                mMovesAvailable[mMovesAvailableCount++].set({from:WASTE, to:foundation, count:1, extra:cardsToDraw});
            }

            for (i in TABLEAU1...TABLEAU7 + 1) {
                var pile:Pile = piles[i];

                if (pile.size() != 0) {
                    var tableauCard:Card = pile.low();

                    if (tableauCard.rank - talonCard.rank != 1 || tableauCard.isRed == talonCard.isRed) {
                        continue;
                    }

                    mMovesAvailable[mMovesAvailableCount++].set({from:WASTE, to:i, count:1, extra:cardsToDraw});
                } else if (talonCard.rank == KING) {
                    mMovesAvailable[mMovesAvailableCount++].set({from:WASTE, to:i, count:1, extra:cardsToDraw});
                    break;
                }
            }
        }

        if (mFoundationCount== 0) { return; }
        //Check foundation to tableau, very rarely needed to solve optimally
        var lastMove:Move = mMovesMade[mMovesMadeCount - 1].copy();
        for (i in FOUNDATION1C...FOUNDATION4H + 1) {
            var pile1:Pile = piles[i];
            var foundationRank:Int = pile1.size();
            if (foundationRank == 0 || foundationRank <= foundationMin) { continue; }

            for (j in TABLEAU1...TABLEAU7 + 1) {
                var pile2:Pile = piles[j];

                if (pile2.size() != 0) {
                    var card:Card = pile2.low();

                    if ((card.foundation & 1) == (i & 1) || card.rank - foundationRank != 1) {
                        continue;
                    }

                    if (lastMove.from != j && lastMove.to != i) {
                        mMovesAvailable[mMovesAvailableCount++].set({from:i, to:j, count:1, extra:0});
                    }
                } else if (foundationRank == KING) {
                    if (lastMove.from != j && lastMove.to != i) {
                        mMovesAvailable[mMovesAvailableCount++].set({from:i, to:j, count:1, extra:0});
                    }
                    break;
                }
            }
        }
    }

    public function resetGame(?mDrawCount:Null<Int> = null) {
        this.mDrawCount = mDrawCount == null ? this.mDrawCount : mDrawCount;
        mRoundCount = 0;
        mFoundationCount= 0;
        mMovesMadeCount = 0;
        mMovesAvailableCount = 0;

        for (i in 0...13) {
            piles[i].reset();
        }

        var i:Int = 0;
        for (j in TABLEAU1...TABLEAU7 + 1) {
            piles[j].addUp(cards[i++]);
            for (k in j + 1...TABLEAU7 + 1) {
                piles[k].addDown(cards[i]);
                ++i;
            }
        }

        i = 51;
        while (i >= 28) {
            piles[STOCK].addUp(cards[i]);
            --i;
        }
    }

    public function shuffle1(dealNumber:Int):Int {
        if (dealNumber != -1) {
            random.setSeed(dealNumber);
        } else {
            dealNumber = random.next1();
            random.setSeed(dealNumber);
        }

        for (i in 0...52) { cards[i].set(i); }

        for (_ in 0...269) {
            var k:Int = random.next1() % 52;
            var j:Int = random.next1() % 52;
            var temp:Card = cards[k];
            cards[k] = cards[j];
            cards[j] = temp;
        }

        return dealNumber;
    }

    public function shuffle2(dealNumber:Int) {
        for (i in 0...26) { cards[i].set(i); }
        for (i in 39...52) { cards[i].set(i - 13); }
        for (i in 26...39) { cards[i].set(i + 13); }

        random.setSeed(dealNumber);
        for (i in 0...7) {
            for (j in 0...52) {
                var r:Int = random.next2() % 52;
                var temp:Card = cards[j];
                cards[j] = cards[r];
                cards[r] = temp;
            }
        }

        var i:Int = 0;
        var j:Int = 51;
        while (i < 26) {
            var temp:Card = cards[j];
            cards[j] = cards[i];
            cards[i] = temp;
            ++i;
            --j;
        }
    }

    public function minimumMovesLeft():Int {
        var waste:Pile = piles[WASTE];
        var wasteSize:Int = waste.size();
        var win:Int = piles[STOCK].size();
        var stockCount:Int = Std.int(win / mDrawCount);
        stockCount += (win % mDrawCount) == 0 ? 0 : 1;
        win += stockCount;
        win += wasteSize;

        var i:Int = wasteSize - 1;
        while (i > 0) {
            var card1:Card = waste.up(i);

            var j = i - 1;
            while (j >= 0) {
                var card2:Card = waste.up(j);

                if (card1.suit == card2.suit && card1.rank > card2.rank) {
                    ++win;
                    break;
                }
                --j;
            }
            --i;
        }

        for (i in TABLEAU1...TABLEAU7 + 1) {
            var pile:Pile = piles[i];
            var pileSize:Int = pile.size();
            var downSize:Int = pile.downSize();
            win += pileSize;
            win += downSize;
            if (downSize == 0) { continue; }

            pileSize -= downSize;
            var mins:Array<Int> = [for (_ in 0...28) 0];

            var j:Int = pileSize - 1;
            while (j >= 0) {
                var card1:Card = pile.up(j);
                mins[card1.suit] = card1.rank;
                --j;
            }

            j = downSize - 1;
            while (j >= 0) {
                var card1:Card = pile.down(j);

                //var rank:Int = mins[card1.suit];
                var cardRank:Int = card1.rank;
                var offset:Int = 0;
                if (mins[card1.suit + 4] == EMPTY) {
                    if (mins[card1.suit + offset] > cardRank) {
                        win++;
                    }
                    mins[card1.suit + offset] = cardRank;
                    --j;
                    continue;
                } else if (mins[card1.suit + offset] > cardRank) {
                    do {
                        win++;
                        mins[card1.suit + offset] = mins[card1.suit + offset + 4];
                        offset += 4;
                    } while (mins[card1.suit + offset] > cardRank);
                }

                do {
                    var temp:Int = mins[card1.suit + offset];
                    mins[card1.suit + offset] = cardRank;
                    cardRank = temp;
                    mins[card1.suit + offset] = mins[card1.suit + offset + 4];
                    offset += 4;
                } while (mins[card1.suit + offset] < cardRank);
                --j;
            }
        }

        return win;
    }

    public function makeAutoMoves() {
        updateAvailableMoves();
        while (mMovesAvailableCount == 1) {
            makeMove(mMovesAvailable[0]);
            updateAvailableMoves();
        }
    }

    public function makeMove(?index:Null<Int> = null, ?move:Move = null) {
        if (index != null && move == null) {
            move = mMovesAvailable[index];
        }

        mMovesMade[mMovesMadeCount++] = move.copy();

        if (move.count == 1) {
            if (move.from == WASTE && move.extra > 0) {
                var stockSize:Int = piles[STOCK].size();
                if (move.extra <= stockSize) {
                    piles[STOCK].removeTalon(piles[WASTE], move.extra);
                } else {
                    mRoundCount ++;
                    stockSize += stockSize;
                    var wasteSize:Int = piles[WASTE].size();
                    stockSize += wasteSize;
                    stockSize += wasteSize;
                    stockSize -= move.extra;
                    if (stockSize > 0) {
                        piles[WASTE].removeTalon(piles[STOCK], stockSize);
                    } else {
                        piles[STOCK].removeTalon(piles[WASTE], -stockSize);
                    }
                }
            }
            piles[move.from].remove(piles[move.to]);

            if (move.to >= FOUNDATION1C) {
                ++mFoundationCount;
            } else if (move.from >= FOUNDATION1C) {
                --mFoundationCount;
            }
        } else {
            piles[move.from].remove(piles[move.to], move.count);
        }

        if (move.from != WASTE && move.extra > 0) {
            piles[move.from].flip();
        }
    }

    public function undoMove() {
        var move:Move = mMovesMade[--mMovesMadeCount];

        if (move.from != WASTE && move.extra > 0) {
            piles[move.from].flip();
        }

        if (move.count == 1) {
            piles[move.to].remove(piles[move.from]);

            if (move.to >= FOUNDATION1C) {
                --mFoundationCount;
            } else if (move.from >= FOUNDATION1C) {
                ++mFoundationCount;
            }

            if (move.from == WASTE && move.extra > 0) {
                var wasteSize:Int = piles[WASTE].size();
                if (move.extra <= wasteSize) {
                    piles[WASTE].removeTalon(piles[STOCK], move.extra);
                } else {
                    mRoundCount --;
                    wasteSize += wasteSize;
                    var stockSize:Int = piles[STOCK].size();
                    wasteSize += stockSize;
                    wasteSize += stockSize;
                    wasteSize -= move.extra;
                    if (wasteSize > 0) {
                        piles[STOCK].removeTalon(piles[WASTE], wasteSize);
                    } else {
                        piles[WASTE].removeTalon(piles[STOCK], -wasteSize);
                    }
                }
            }
        } else {
            piles[move.to].remove(piles[move.from], move.count);
        }
    }

    public function getMoveAvailable(index:Int):Move {
        return mMovesAvailable[index];
    }

    public function getMoveMade(index:Int):Move {
        return mMovesMade[index];
    }

    public function loadSolitaire(cardSet:String):Bool {
        var used:Array<Int> = [for (_ in 0...52) 0];
        if (cardSet.length < 156) { return false; }
        for (i in 0...52) {
            var suit:Int = (cardSet.charCodeAt(i * 3 + 2) ^ 0x30) - 1;
            if (suit < CLUBS || suit > HEARTS) { return false; }

            if (suit >= SPADES) {
                suit = (suit == SPADES) ? HEARTS : SPADES;
            }

            var rank:Int = (cardSet.charCodeAt(i * 3) ^ 0x30) * 10 + (cardSet.charCodeAt(i * 3 + 1) ^ 0x30);
            if (rank < ACE || rank > KING) { return false; }

            var value:Int = suit * 13 + rank - 1;
            if (used[value] == 1) { return false; }
            used[value] = 1;
            cards[i].set(value);
        }

        return true;
    }

    public function getSolitaire():String {
        var cardSet:String = "";
        for (i in 0...52) {
            var c:Card = cards[i];
            var suit:Int = c.suit;

            if (suit >= 2) {
                suit = (suit == 2) ? 3 : 2;
            }
            suit++;

            if (c.rank < 10) {
                cardSet = cardSet + '0' + String.fromCharCode(c.rank ^ 0x30) + String.fromCharCode(suit ^ 0x30);
            } else {
                cardSet = cardSet + '1' + String.fromCharCode((c.rank - 10) ^ 0x30) + String.fromCharCode(suit ^ 0x30);
            }
        }
        return cardSet;
    }

    public function loadPysol(cardSet:String):Bool {
        var used:Array<Int> = [for (_ in 0...52) 0];
        if (cardSet.length < 211) { return false; }
        var j:Int = 7;
        for (i in 28...52) {
            var rank:Int = cardSet.charAt(j) == 'A' ? ACE : (cardSet.charAt(j) == 'T' ? TEN : (cardSet.charAt(j) == 'J' ? JACK : (cardSet.charAt(j) == 'Q' ? QUEEN : (cardSet.charAt(j) == 'K' ? KING : cardSet.charCodeAt(j) ^ 0x30))));
            if (rank < ACE || rank > KING) { return false; }
            j++;

            var suit:Int = cardSet.charAt(j) == 'C' ? CLUBS : (cardSet.charAt(j) == 'D' ? DIAMONDS : (cardSet.charAt(j) == 'S' ? SPADES : HEARTS));
            if (suit < CLUBS || suit > HEARTS) { return false; }
            j += 2;

            var value:Int = suit * 13 + rank - 1;
            if (used[value] == 1) { return false; }
            used[value] = 1;
            cards[i].set(value);
        }

        final order:Array<Int> = [0, 1, 7, 2, 8, 13, 3, 9, 14, 18, 4, 10, 15, 19, 22, 5, 11, 16, 20, 23, 25, 6, 12, 17, 21, 24, 26, 27];
        for (i in 0...28) {
            while (j < cardSet.length && (cardSet.charAt(j) == '\r' || cardSet.charAt(j) == '\n' || cardSet.charAt(j) == '\t' || cardSet.charAt(j) == ' ' || cardSet.charAt(j) == ':' || cardSet.charAt(j) == '<')) { j++; }
            if (j + 1 >= cardSet.length) { return false; }

            var rank:Int = cardSet.charAt(j) == 'A' ? ACE : (cardSet.charAt(j) == 'T' ? TEN : (cardSet.charAt(j) == 'J' ? JACK : (cardSet.charAt(j) == 'Q' ? QUEEN : (cardSet.charAt(j) == 'K' ? KING : cardSet.charCodeAt(j) ^ 0x30))));
            if (rank < ACE || rank > KING) { return false; }
            j++;

            var suit:Int = cardSet.charAt(j) == 'C' ? CLUBS : (cardSet.charAt(j) == 'D' ? DIAMONDS : (cardSet.charAt(j) == 'S' ? SPADES : HEARTS));
            if (suit < CLUBS || suit > HEARTS) { return false; }
            j += 3;

            var value:Int = suit * 13 + rank - 1;
            if (used[value] == 1) { return false; }
            used[value] = 1;
            cards[order[i]].set(value);
        }
        return true;
    }

    public function getPysol():String {
        var cardSet:String = "Talon: ";
        for (i in 28...52) {
            var c:Card = cards[i];

            cardSet = cardSet + RANKS.charAt(c.rank) + SUITS.charAt(c.suit);
            if (i < 51) { cardSet = cardSet + " "; }
        }

        final order:Array<Int> = [0, 1, 7, 2, 8, 13, 3, 9, 14, 18, 4, 10, 15, 19, 22, 5, 11, 16, 20, 23, 25, 6, 12, 17, 21, 24, 26, 27 ];
        var i:Int = 0;
        var j:Int = 0;
        while (j < 7) {
            cardSet = cardSet + '\n';
            var k:Int = 0;
            while (k <= j) {
                var c:Card = cards[order[i]];

                if (k < j) {
                    cardSet = cardSet + '<' + RANKS.charAt(c.rank) + SUITS.charAt(c.suit) + "> ";
                } else {
                    cardSet = cardSet + RANKS.charAt(c.rank) + SUITS.charAt(c.suit);
                }
                ++k;
                ++i;
            }
            ++j;
        }
        return cardSet;
    }

    public function setDrawCount(mDrawCount:Int) {
        this.mDrawCount = mDrawCount;
    }

    public function gameState():HashKey {
        var order:Array<Int> = [TABLEAU1, TABLEAU2, TABLEAU3, TABLEAU4, TABLEAU5, TABLEAU6, TABLEAU7];
        var current:Int = 1;
        //sort the piles
        while (current < 7) {
            var search:Int = current;

            do {
                if (piles[order[search - 1]].highValue() <= piles[order[search]].highValue()) {
                    break;
                }

                var temp:Int = order[--search];
                order[search] = order[search + 1];
                order[search + 1] = temp;
            } while (search > 0);

            ++current;
        }

        var key:HashKey = new HashKey();
        var z:Int = 0;
        key.set(z++, (piles[FOUNDATION1C].size() << 4) | (piles[FOUNDATION2D].size() + 1));
        key.set(z++, (piles[FOUNDATION3S].size() << 4) | piles[FOUNDATION4H].size());

        var bits:Int = 5;
        var mask:Int = mRoundCount ;
        for (i in 0...7) {
            var pile:Pile = piles[order[i]];
            var upSize:Int = pile.upSize();

            var added:Int = 10;
            mask <<= 6;
            if (upSize > 0) {
                added += upSize - 1;
                mask |= pile.up(0).value + 1;
            }
            bits += added;
            mask <<= 4;
            mask |= upSize;
            for (j in 1...upSize) {
                mask <<= 1;
                mask |= pile.up(j).suit >> 1;
            }

            bits += 21 - added;
            mask <<= 21 - added;
            do {
                bits -= 8;
                key.set(z++, (mask >> bits) & 255);
            } while (bits >= 8);
        }
        if (bits > 0) {
            key.set(z, mask & 255);
        }

        return key;
    }

    public function getMoveInfo(move:Move):String {
        var ss:String = "";
        var stockSize:Int = piles[STOCK].size();
        var wasteSize:Int = piles[WASTE].size();

        var fromRank:String = '0';
        var fromSuit:String = 'X';

        if (move.extra > 0) {
            if (move.from != WASTE) {
                if (move.count > 1) {
                    ss = ss + "Move " + move.count + " cards from tableau " + move.from + " on to tableau " + move.to;
                } else {
                    fromRank = RANKS.charAt(piles[move.from].low().rank);
                    fromSuit = SUITS.charAt(piles[move.from].low().suit);
                    ss = ss + "Move " + fromRank + fromSuit + " from " + (move.from == WASTE ? "waste" : (move.from >= FOUNDATION1C ? "foundation" : "tableau "));
                    if (move.from >= TABLEAU1 && move.from <= TABLEAU7) { ss = ss + move.from; }
                    ss = ss + " on to " + (move.to >= FOUNDATION1C ? "foundation" : "tableau ");
                    if (move.to >= TABLEAU1 && move.to <= TABLEAU7) { ss = ss + move.to; }
                }
                ss = ss + " and flip tableau " + move.from;
            } else {
                var drawAmount:Int = 0;
                if (move.extra <= stockSize) {
                    drawAmount = Std.int(move.extra / mDrawCount + ((move.extra % mDrawCount) == 0 ? 0 : 1));
                    fromRank = RANKS.charAt(piles[STOCK].up(stockSize - move.extra).rank);
                    fromSuit = SUITS.charAt(piles[STOCK].up(stockSize - move.extra).suit);
                } else {
                    drawAmount = move.extra - stockSize - stockSize - wasteSize;
                    drawAmount = Std.int(drawAmount / mDrawCount + ((drawAmount % mDrawCount) == 0 ? 0 : 1));
                    drawAmount += Std.int(stockSize / mDrawCount + ((stockSize % mDrawCount) == 0 ? 0 : 1));

                    var cardsToMove:Int = stockSize + stockSize + wasteSize + wasteSize - move.extra;
                    if (cardsToMove > 0) {
                        fromRank = RANKS.charAt(piles[WASTE].up(wasteSize - cardsToMove - 1).rank);
                        fromSuit = SUITS.charAt(piles[WASTE].up(wasteSize - cardsToMove - 1).suit);
                    } else {
                        fromRank = RANKS.charAt(piles[STOCK].up(stockSize + cardsToMove).rank);
                        fromSuit = SUITS.charAt(piles[STOCK].up(stockSize + cardsToMove).suit);
                    }
                }
                ss = ss + "Draw " + drawAmount + (drawAmount == 1 ? " time " : " times ") + "and move " + fromRank + fromSuit + " from waste on to " + (move.to >= FOUNDATION1C ? "foundation" : "tableau ");
                if (move.to >= TABLEAU1 && move.to <= TABLEAU7) { ss = ss + move.to; }
            }
        } else if (move.count > 1) {
            ss = ss + "Move " + move.count + " cards from tableau " + move.from + " on to tableau " + move.to;
        } else {
            fromRank = RANKS.charAt(piles[move.from].low().rank);
            fromSuit = SUITS.charAt(piles[move.from].low().suit);
            ss = ss + "Move " + fromRank + fromSuit + " from " + (move.from == WASTE ? "waste" : (move.from >= FOUNDATION1C ? "foundation" : "tableau "));
            if (move.from >= TABLEAU1 && move.from <= TABLEAU7) { ss = ss + move.from; }
            ss = ss + " on to " + (move.to >= FOUNDATION1C ? "foundation" : "tableau ");
            if (move.to >= TABLEAU1 && move.to <= TABLEAU7) { ss = ss + move.to; }
        }
        return ss;
    }

    public function gameDiagram():String {
        var ss:String = "";
        for (i in 0...13) {
            if (i < 10) {
                ss = ss + ' ';
            }
            ss = ss + i + ": ";
            var p:Pile = piles[i];
            var size:Int = p.upSize();
            var j:Int = size - 1;
            while (j >= 0) {
                var c:Card = p.up(j);
                var rank:String = RANKS.charAt(c.rank);
                var suit:String = c.suit != NONE ? SUITS.charAt(c.suit) : 'X';
                ss = ss + rank + suit + ' ';
                --j;
            }
            size = p.downSize();
            j = size - 1;
            while (j >= 0) {
                var c:Card = p.down(j);
                var rank:String = RANKS.charAt(c.rank);
                var suit:String = c.suit != NONE ? SUITS.charAt(c.suit) : 'X';
                ss = ss + '-' + rank + suit;
                --j;
            }
            ss = ss + '\n';
        }
        ss = ss + "Minimum Moves Needed: " + minimumMovesLeft();
        return ss;
    }

    public function gameDiagramPysol():String {
        var ss:String = "";
        ss = ss + "Foundations: H-" + RANKS.charAt(piles[FOUNDATION4H].size()) + " C-" + RANKS.charAt(piles[FOUNDATION1C].size()) + " D-" + RANKS.charAt(piles[FOUNDATION2D].size()) + " S-" + RANKS.charAt(piles[FOUNDATION3S].size());
        ss = ss + "\nTalon: ";

        var waste:Pile = piles[WASTE];
        var size:Int = waste.upSize();
        var j:Int = size - 1;
        while (j >= 0) {
            var c:Card = waste.up(j);
            var rank:String = RANKS.charAt(c.rank);
            var suit:String = c.suit != NONE ? SUITS.charAt(c.suit) : 'X';
            ss = ss + rank + suit + ' ';
            --j;
        }
        ss = ss + "==> ";

        var stock:Pile = piles[STOCK];
        size = stock.upSize();
        j = size - 1;
        while (j >= 0) {
            var c:Card = stock.up(j);
            var rank:String = RANKS.charAt(c.rank);
            var suit:String = c.suit != NONE ? SUITS.charAt(c.suit) : 'X';
            ss = ss + rank + "" + suit + ' ';
            --j;
        }
        ss = ss + "<==";

        for (i in TABLEAU1...TABLEAU7 + 1) {
            ss = ss + "\n:";
            var p:Pile = piles[i];
            size = p.downSize();
            for (j in 0...size) {
                var c:Card = p.down(j);
                var rank:String = RANKS.charAt(c.rank);
                var suit:String = c.suit != NONE ? SUITS.charAt(c.suit) : 'X';
                ss = ss + " <" + rank + suit + ">";
            }
            size = p.upSize();
            for (j in 0...size) {
                var c:Card = p.up(j);
                var rank:String = RANKS.charAt(c.rank);
                var suit:String = c.suit != NONE ? SUITS.charAt(c.suit) : 'X';
                ss = ss + ' ' + rank + suit;
            }
        }

        return ss;
    }

    public function addMove(m:Move, stockSize:Int, wasteSize:Int, mDrawCount:Int, combine:Bool):String {
        var ss:String = "";
        if (m.extra > 0) {
            if (m.from != WASTE) {
                if (m.count > 1) {
                    if (!combine) {
                        ss = ss + PILES.charAt(m.from) + PILES.charAt(m.to) + '-' + m.count + " F" + m.from + ' ';
                    } else {
                        ss = ss + '[' + PILES.charAt(m.from) + PILES.charAt(m.to) + '-' + m.count + " F" + m.from + "] ";
                    }
                } else if (!combine) {
                    ss = ss + PILES.charAt(m.from) + PILES.charAt(m.to) + " F" + m.from + ' ';
                } else {
                    ss = ss + '[' + PILES.charAt(m.from) + PILES.charAt(m.to) + " F" + m.from + "] ";
                }
            } else if (!combine) {
                if (m.extra <= stockSize) {
                    ss = ss + "DR" + (m.extra / mDrawCount + ((m.extra % mDrawCount) == 0 ? 0 : 1)) + ' ' + PILES.charAt(m.from) + PILES.charAt(m.to) + ' ';
                } else {
                    var temp:Int = Std.int(stockSize / mDrawCount + ((stockSize % mDrawCount) == 0 ? 0 : 1));
                    if (temp != 0) { ss = ss + "DR" + temp + ' '; }
                    ss = ss + "NEW ";
                    temp = m.extra - stockSize - stockSize - wasteSize;
                    temp = Std.int(temp / mDrawCount + ((temp % mDrawCount) == 0 ? 0 : 1));
                    ss = ss + "DR" + temp + ' ' + PILES.charAt(m.from) + PILES.charAt(m.to) + ' ';
                }
            } else if (m.extra <= stockSize) {
                ss = ss + "[DR" + (m.extra / mDrawCount + ((m.extra % mDrawCount) == 0 ? 0 : 1)) + ' ' + PILES.charAt(m.from) + PILES.charAt(m.to) + "] ";
            } else {
                var temp:Int = m.extra - stockSize - stockSize - wasteSize;
                temp = Std.int(temp / mDrawCount + ((temp % mDrawCount) == 0 ? 0 : 1));
                temp += Std.int(stockSize / mDrawCount + ((stockSize % mDrawCount) == 0 ? 0 : 1));
                ss = ss + "[DR" + temp + ' ' + PILES.charAt(m.from) + PILES.charAt(m.to) + "] ";
            }
        } else if (m.count > 1) {
            ss = ss + PILES.charAt(m.from) + PILES.charAt(m.to) + '-' + m.count + ' ';
        } else {
            ss = ss + PILES.charAt(m.from) + PILES.charAt(m.to) + ' ';
        }
        return ss;
    }

    public function movesAvailable():String {
        //Returns moves available for the current state. Flip moves are combined with the move that caused it in []. See below for move representation.
        var ss:String = "";
        for (i in 0...mMovesAvailableCount) {
            var m:Move = mMovesAvailable[i];
            ss = ss + addMove(m, piles[STOCK].size(), piles[WASTE].size(), mDrawCount, true);
        }
        return ss;
    }

    public function movesMade():String {
        //Returns moves made so far in the current game.
        //DR# is a draw move that is done # number of times. ie) DR2 means draw twice, if draw count > 1 it is still DR2.
        //NEW is to represent the moving of cards from the Waste pile back to the stock pile. A New round.
        //F# means to flip the card on tableau pile #.
        //XY means to move the top card from pile X to pile Y.
        //X will be 1 through 7, W for Waste, or a foundation suit character. 'C'lubs, 'D'iamonds, 'S'pades, 'H'earts
        //Y will be 1 through 7 or the foundation suit character.
        //XY-# is the same as above except you are moving # number of cards from X to Y.
        var ss:String = "";
        var moves:Int = mMovesMadeCount;
        resetGame(mDrawCount);
        for (i in 0...moves) {
            var m:Move = mMovesMade[i];
            ss = ss + addMove(m, piles[STOCK].size(), piles[WASTE].size(), mDrawCount, false);
            makeMove(m);
        }
        return ss;
    }

    public function movesAvailableCount():Int {
        return mMovesAvailableCount;
    }

    public function movesMadeNormalizedCount():Int {
        var movesTotal:Int = 0;
        var stockSize:Int = 24;
        var wasteSize:Int = 0;
        for (i in 0...mMovesMadeCount) {
            var m:Move = mMovesMade[i];
            movesTotal++;
            if (m.extra > 0) {
                if (m.from == WASTE) {
                    var temp:Int = stockSize;
                    if (m.extra <= stockSize) {
                        temp = m.extra;
                        stockSize -= temp;
                        wasteSize += temp - 1;
                    } else {
                        movesTotal += Std.int(temp / mDrawCount);
                        movesTotal += (temp % mDrawCount) == 0 ? 0 : 1;
                        temp = m.extra;
                        temp -= wasteSize;
                        temp -= stockSize;
                        temp -= stockSize;
                        stockSize += wasteSize - temp;
                        wasteSize = temp - 1;
                    }
                    movesTotal += Std.int(temp / mDrawCount);
                    movesTotal += (temp % mDrawCount) == 0 ? 0 : 1;
                } else {
                    movesTotal++;
                }
            } else if (m.from == WASTE) {
                wasteSize--;
            }
        }
        return movesTotal;
    }

    public function movesMadeCount():Int {
        return mMovesMadeCount;
    }

    public function foundationCount():Int {
        return mFoundationCount;
    }

    public function roundCount():Int {
        return mRoundCount ;
    }

    public function drawCount() {
        return mDrawCount;
    }

    public function movesAdded(move:Move):Int {
        var movesAdded:Int = 1;
        var wasteSize:Int = piles[WASTE].size();
        var stockSize:Int = piles[STOCK].size();
        if (move.extra > 0) {
            if (move.from == WASTE) {
                if (move.extra <= stockSize) {
                    movesAdded += Std.int(move.extra / mDrawCount);
                    movesAdded += (move.extra % mDrawCount) == 0 ? 0 : 1;
                } else {
                    movesAdded += Std.int(stockSize / mDrawCount);
                    movesAdded += (stockSize % mDrawCount) == 0 ? 0 : 1;
                    var temp:Int = move.extra;
                    temp -= wasteSize;
                    temp -= stockSize;
                    temp -= stockSize;
                    movesAdded += Std.int(temp / mDrawCount);
                    movesAdded += (temp % mDrawCount) == 0 ? 0 : 1;
                }
            } else {
                movesAdded++;
            }
        }
        return movesAdded;
    }

    public function get(index:Int) {
        return mMovesMade[index];
    }
}

// TODO: Port multithreaded code
/*
class SolitaireWorker {
private:
	stack<shared_ptr<MoveNode>> open[512];
	Move bestSolution[512];
	Solitaire * solitaire;
	mutex mtx;
	Int openCount, maxFoundationCount, bestSolutionMoveCount, startMoves, maxClosedCount;

	void RunMinimalWorker(void * closed);
	void RunFastWorker();
public:
	SolitaireWorker(Solitaire & solitaire, Int maxClosedCount);

	SolveResult Run(Int numThreads);
    SolitaireWorker::SolitaireWorker(Solitaire & solitaire, Int maxClosedCount) {
        this->solitaire = &solitaire;
        this->maxClosedCount = maxClosedCount;
    }
    void SolitaireWorker::RunMinimalWorker(void * closedPointer) {
        HashMap<Int> & closed = *reinterpret_cast<HashMap<Int>*>(closedPointer);
        Move movesToMake[512];
        shared_ptr<MoveNode> firstNode = null;
        shared_ptr<MoveNode> node = null;
        Solitaire s = *solitaire;
        Int doneCount = 10;
        while (closed.size() < maxClosedCount && doneCount > 0) {
            mtx.lock();
            //Check for lowest score length
            Int index = startMoves;
            while (index < 512 && open[index].size() == 0) { index++; }

            //End solver if no more states
            if (index >= 512) {
                mtx.unlock();
                doneCount--;
                this_thread::sleep_for(chrono::milliseconds(1));
                continue;
            }

            doneCount = 10;

            //Get next state to evaluate
            --openCount;
            firstNode = open[index][open[index].length - 1];
            open[index].pop();
            mtx.unlock();

            //Initialize game to the found state
            s.resetGame();
            Int movesTotal = 0;
            node = firstNode;
            while (node != null) {
                movesToMake[movesTotal++] = node.value;
                node = node.parent;
            }
            while (movesTotal > 0) {
                s.makeMove(movesToMake[--movesTotal]);
            }

            //Make any auto moves
            s.updateAvailableMoves();
            while (s.mMovesAvailableCount() == 1) {
                var move:Move = s.GetMoveAvailable(0);
                s.makeMove(move);
                firstNode = new MoveNode(move, firstNode);
                s.updateAvailableMoves();
            }
            movesTotal = s.movesMadeNormalizedCount();


            //Check for best solution to foundations
            if (s.foundationCount() > maxFoundationCount || (s.foundationCount() == maxFoundationCount && bestSolutionMoveCount > movesTotal)) {
                mtx.lock();
                if (s.foundationCount() > maxFoundationCount || (s.foundationCount() == maxFoundationCount && bestSolutionMoveCount > movesTotal)) {
                    bestSolutionMoveCount = movesTotal;
                    maxFoundationCount = s.foundationCount();

                    //Save solution
                    for (Int i = s.movesMadeCount() - 1; i >= 0; i--) {
                        bestSolution[i] = s[i];
                    }
                    bestSolution[s.movesMadeCount()].count = 255;
                }
                mtx.unlock();
            } else if (maxFoundationCount == 52) {
                //Dont check state if above or equal to current best solution
                var helper:Int = s.minimumMovesLeft();
                helper += movesTotal;
                if (helper >= bestSolutionMoveCount) { continue; }
            }

            Int mMovesAvailableCount = s.movesAvailableCount();
            //Make available moves and add them to be evaulated
            for (i in 0...mMovesAvailableCount; i++) {
                var move:Move = s.GetMoveAvailable(i);
                var movesAdded:Int = s.movesAdded(move);

                s.makeMove(move);

                movesAdded += movesTotal;
                movesAdded += s.minimumMovesLeft();
                if (maxFoundationCount < 52 || movesAdded < bestSolutionMoveCount) {
                    var helper:Int = movesAdded;
                    helper += 52 - s.foundationCount() + s.roundCount();
                    var key:HashKey = s.gameState();

                    mtx.lock();
                    var result:KeyValue<Int> = closed.add(key, movesAdded);
                    if (result == null || result.value > movesAdded) {
                        node = new MoveNode(move, firstNode);
                        if (result != null) { result.value = movesAdded; }

                        ++openCount;
                        open[helper].push(node);
                    }
                    mtx.unlock();
                }

                s.undoMove();
            }
        }
    }
    SolveResult SolitaireWorker::Run(Int numThreads) {
        solitaire->makeAutoMoves();
        if (solitaire->movesAvailableCount() == 0) { return solitaire->foundationCount() == 52 ? SolvedMinimal : Impossible; }

        openCount = 1;
        maxFoundationCount = solitaire->foundationCount();
        bestSolutionMoveCount = 512;
        bestSolution[0].count = 255;
        startMoves = solitaire->minimumMovesLeft() + solitaire->movesMadeNormalizedCount();
        Int powerOf2 = 1;
        while (maxClosedCount > (1 << (powerOf2 + 2))) {
            powerOf2++;
        }
        HashMap<Int> * closed = new HashMap<Int>(powerOf2);

        shared_ptr<MoveNode> firstNode = solitaire->movesMadeCount() > 0 ? new MoveNode(solitaire->getMoveMade(solitaire->movesMadeCount() - 1)) : null;
        shared_ptr<MoveNode> node = firstNode;
        for (Int i = solitaire->movesMadeCount() - 2; i >= 0; i--) {
            node.parent = new MoveNode(solitaire->getMoveMade(i));
            node = node.parent;
        }
        open[startMoves].push(firstNode);

        thread * threads = new thread[numThreads];
        for (i in 0...numThreads; i++) {
            threads[i] = thread(&SolitaireWorker::RunMinimalWorker, this, (void*)closed);
            this_thread::sleep_for(chrono::milliseconds(23));
        }

        for (i in 0...numThreads; i++) {
            threads[i].join();
        }
        delete[] threads;

        //Reset game to best solution found
        solitaire->resetGame();
        for (i in 0...bestSolution[i].count < 255) {
            solitaire->makeMove(bestSolution[i]);
        }

        SolveResult result = closed->Size() >= maxClosedCount ? (maxFoundationCount == 52 ? SolvedMayNotBeMinimal : CouldNotComplete) : (maxFoundationCount == 52 ? SolvedMinimal : Impossible);
        delete closed;
        return result;
    }
}
*/
