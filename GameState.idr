module GameState
import Spec
import Effects

Coord : Type
Coord = (Int, Int)

data Orientation = ToLeft | ToRight | ToTop | ToBottom
||| A tail segment contains the headward endpoint coordinate and the length
||| of the segment. A positive length means that the headward end is down
||| and to the right.
data TailSegment = Seg Orientation Nat Coord

||| A list of 'TailSegment's, with the head at the beginning.
Snake : Type
Snake = List TailSegment

retract : Snake -> Snake
retract [] = []
retract [Seg dir (S length) end] = [Seg dir length end]
retract [Seg dir Z end] = []
retract (Seg dir length end :: rest) = Seg dir length end :: retract rest

||| The pieces of game state that are shared across all phases
record Universal : Type where
  MkU : (windowDimensions : (Int, Int)) -> (params : valuesFor serpentParams) -> Universal

||| The concrete representation of the game state.
data Game : Phase -> Type where
  InGame : Snake -> (walls : List Coord) -> (food : List Coord) -> (score : Nat) -> (univ : Universal) ->
           Game (Playing isPaused (params univ))
  InMenu : (vals : valuesFor inputs) -> (univ : Universal) -> Game (Menu inputs (params univ))
  Dead : Game (Playing False rules) -> (univ : Universal) -> Game (GameOver (params univ))
  IntroScreen : (univ : Universal) -> Game (MainMenu (params univ))

data Collision = Food | Wall

newHead : Orientation -> Coord -> Coord
newHead ToLeft (x, y) = (x-1, y)
newHead ToRight (x, y) = (x+1, y)
newHead ToTop (x, y) = (x, y-1)
newHead ToBottom (x, y) = (x, y+1)

extend : Direction -> Snake -> Snake
extend _ [] = []
extend Straight (Seg o l h :: segs) = Seg o (S l) (newHead o h) :: segs
extend dir (Seg o l h :: segs) =
    Seg (turn dir o) (newLen dir l) (newHead (turn dir o) h) :: Seg o l h :: segs
  where turn : Direction -> Orientation -> Orientation
        turn TurnLeft ToLeft = ToBottom
        turn TurnLeft ToRight = ToTop
        turn TurnLeft ToTop = ToLeft
        turn TurnLeft ToBottom = ToRight
        turn TurnRight ToLeft = ToTop
        turn TurnRight ToRight = ToBottom
        turn TurnRight ToTop = ToRight
        turn TurnRight ToBottom = ToLeft
        turn Straight o = o
        newLen : Direction -> Nat -> Nat
        newLen Straight l = S l
        newLen _ l = 1

doMove : Direction -> Game (Playing False rules) -> (Game (Playing False rules), Maybe Collision)
doMove relDir (InGame snake walls food score univ) = (InGame newSnake newWalls newFood newScore univ, coll)
  where newSnake = extend relDir snake
        newWalls = walls -- later should check the rules for wall creation
        newFood = food -- same for food creation
        coll = Nothing -- ?checkCollision
        newScore = score -- ?score

retractSnake : Game (Playing paused rules) -> Game (Playing paused rules)
retractSnake (InGame snake walls food score univ) =
  InGame (retract snake) walls food score univ

instance Handler (Serpent Game) m where

  handle (InGame snake walls food score (MkU dims ps)) (Turn d) k =
    let ingame = InGame snake walls food score (MkU dims ps)
        (next, collision) = doMove d ingame
        InGame snake walls food score (MkU dims ps) = next
    in case collision of
         Nothing => k False (retractSnake next)
         Just Food => k False next
         Just Wall => k True (Dead (retractSnake next) (MkU dims ps))
  handle (InGame {isPaused} snake walls food score univ) TogglePause k =
    k () (InGame {isPaused = not isPaused} snake walls food score univ)
  handle (InGame _ _ _ _ univ) Quit k = k () (IntroScreen univ)
  handle (InGame _ _ _ _ univ) (Restart new) k = k () new

  handle (InMenu pending univ) (Update param upd) k =
    let new = updateParam pending param upd
    in k (getValue param new) (InMenu new univ)
  handle (InMenu pending univ) ExitMenu k =
    k () (IntroScreen univ)
  handle (InMenu pending (MkU dims ps)) SaveMenu k = k (Just pending) (IntroScreen (MkU dims pending)) -- ?validate

  handle (Dead gameover univ) (PlayAgain newState) k = k () newState
  handle (Dead gameover univ) Finished k = k () (IntroScreen univ)

  handle (IntroScreen univ) (NewGame st) k = k () st
  handle (IntroScreen (MkU dim params)) (Randomize newRules) k =
    k newRules (IntroScreen (MkU dim newRules))
  handle (IntroScreen univ) Reset k = 
        k () (conv (IntroScreen (record { params = defaults serpentParams } univ)))
    where obv : params (set_params p u) = p
          obv {p} {u = MkU dims old} = Refl
          conv : Game (MainMenu (params (set_params p u))) -> Game (MainMenu p)
          conv g = replace {P = \rules => Game (MainMenu rules) } obv g
  handle (IntroScreen univ) Tweak k = k () (InMenu (params univ) univ)

  handle st Get k = k st st

GAME : Phase -> EFFECT
GAME ph = GameEff Game ph
