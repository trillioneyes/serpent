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
  MkU : (windowDimensions : (Int, Int)) -> (params : List MenuInput) -> Universal

||| The concrete representation of the game state.
data Game : Phase -> Type where
  InGame : Snake -> (walls : List Coord) -> (food : List Coord) -> (score : Nat) -> Universal ->
           Game (Playing isPaused)
  InMenu : (pending : List MenuInput) -> Universal -> Game (Menu pending)
  Dead : Game (Playing False) -> Game GameOver
  IntroScreen : Universal -> Game (Playing False) -> Game MainMenu

data Collision = Food | Wall
doMove : Direction -> Game (Playing False) -> (Game (Playing False), Maybe Collision)

instance Handler (Serpent Game) m where
  handle ingame (Turn d) k =
    let InGame snake walls food score univ = ingame
        (next, collision) = doMove d ingame
    in case collision of
         Nothing => k False next
         Just Food => k False next -- need to grow the snake
         Just Wall => k True (Dead next)
  handle (InGame {isPaused} snake walls food score univ) TogglePause k =
    k () (InGame {isPaused = not isPaused} snake walls food score univ)
  handle (InGame _ _ _ _ univ) Quit k = k () (IntroScreen univ ?randomGame)
  handle (InGame _ _ _ _ univ) Restart k = k () ?randomGame2

  handle (InMenu pending univ) (Update param new) k =
    k ?newParamValue (InMenu (updateParam pending param new) univ)
      
