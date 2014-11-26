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

||| A list of 'TailSegment's, with the head at the end.
Snake : Type
Snake = List TailSegment

advance : Snake -> Snake
advance [] = []
advance (Seg dir (S length) end :: rest) = Seg dir length end :: rest
advance (Seg dir Z end :: rest) = rest

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
doMove : Direction -> Game (Playing False rules) -> (Game (Playing False rules), Maybe Collision)

instance Handler (Serpent Game) m where
  handle (InGame snake walls food score univ) (Turn d) k =
    let ingame = (InGame snake walls food score univ)
        (next, collision) = doMove d ingame
    in case collision of
         Nothing => k False next
         Just Food => k False next -- need to grow the snake
         Just Wall => k True (Dead next univ)
  handle (InGame {isPaused} snake walls food score univ) TogglePause k =
    k () (InGame {isPaused = not isPaused} snake walls food score univ)
  handle (InGame _ _ _ _ univ) Quit k = k () (IntroScreen univ)
  handle (InGame _ _ _ _ univ) (Restart new) k = k () new

  handle (InMenu pending univ) (Update param new) k =
    k ?newParamValue (InMenu (updateParam pending param new) univ)
  handle (InMenu pending univ) ExitMenu k =
    k () (IntroScreen univ)
  handle (InMenu {inputs} pending univ) SaveMenu k = ?validate

  handle (Dead gameover univ) (PlayAgain newState) k = k () newState
  handle (Dead gameover univ) Finished k = k () (IntroScreen univ)

  handle (IntroScreen univ) (NewGame st) k = k () st
  handle (IntroScreen univ) (Randomize newRules) k =
    let new = ?newUniv in k newRules new
  handle (IntroScreen univ) Reset k = 
        k (defaults serpentParams) (replace obv (IntroScreen (record { params = defaults serpentParams } univ)))
    where obv : params (set_params p u) = p
          obv {p} {u} = believe_me (Refl {p}) -- apparently these don't compute >.>
