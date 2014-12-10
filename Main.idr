module Main
import CallbackStack
import GameState
import Draw
import Interact
import Effects

record InputState : Type where
  MkI : {button : Maybe Char} -> InputState

data Frames : Nat -> Effect where
  Tick : (millis : Float) -> { (Float, Float) } (Frames fps) Bool

instance Handler (Frames fps) m where
  handle (last, elapsed) (Tick delta) k =
      k ticked (if ticked then nextFrame else last, elapsed + delta)
    where nextFrame = last + 1000/cast (cast {to=Int} fps)
          ticked = elapsed + delta >= nextFrame

FPS : Nat -> EFFECT
FPS fps = MkEff (Float, Float) (Frames fps)

tick : Float -> { [FPS n] } Eff Bool
tick {n} delta = call (Tick delta)

GameClock : EFFECT
GameClock = 'GameClock ::: FPS 5

stepGame : InputState -> Float ->
           { [GAME (Playing False rules), GameClock]
             ==> {hitWall}
             [GAME (if hitWall then GameOver rules else Playing False rules), GameClock]
           } Eff Bool
stepGame (MkI {button}) delta = do
  if !('GameClock :- tick delta)
     then turn (case button of
                    Just 'a' => TurnLeft
                    Just 'd' => TurnRight
                    _ => Straight)
     else value False

startState : Game (Playing False rules)
startState {rules} = InGame snake [] [] 0 (MkU (600, 400) rules)
  where snake = [Seg ToRight 4 (2, 0)]

drawGame : { [GAME (Playing isPaused rules), CANVAS] } Eff ()
drawGame {rules} = do
  clear
  InGame snake walls food score (MkU _ rules) <- get
  drawSnake snake
  traverse_ (rectCell Brown) walls
  traverse_ (rectCell Red) food
 where rectCell : Color -> Coord -> { [CANVAS] } Eff ()
       rectCell color (cx, cy) = rect (cx - 10) (cx + 10) (cy - 10) (cy + 10) color
       traverse_ : (a -> { [CANVAS] } Eff ()) -> List a -> { [CANVAS] } Eff ()
       traverse_ _ [] = value ()
       traverse_ f (x::xs) = do
         f x
         traverse_ f xs

SERPENT : Phase -> List EFFECT
SERPENT ph = [GAME ph, GameClock, NONBLOCKING, CANVAS, CONTROLS]

controlDirection : { [GAME (Playing p rules), CONTROLS] } Eff Direction
controlDirection {rules} = do
  InGame snake walls food score (MkU params rules) <- get
  wanted <- readCommand
  let now = the Orientation $ case snake of
    Seg dir _ _ :: _ => dir
    _ => ToTop
  return $ case (now, wanted) of
    (_, Just TurnLeft) => TurnLeft
    (_, Just TurnRight) => TurnRight
    (_, Just Forward) => Straight
    (ToLeft, Just FaceTop) => TurnRight
    (ToRight, Just FaceTop) => TurnLeft
    (ToTop, Just FaceLeft) => TurnLeft
    (ToBottom, Just FaceLeft) => TurnRight
    (ToTop, Just FaceRight) => TurnRight
    (ToBottom, Just FaceRight) => TurnLeft
    (ToRight, Just FaceBottom) => TurnRight
    (ToLeft, Just FaceBottom) => TurnLeft
    _ => Straight

endless : { [GAME (Playing False rules), CONTROLS] } Eff ()
endless = do
  hit <- turn !controlDirection
  case hit of
    True => playAgain startState
    False => value ()

dummyGame : { SERPENT (Playing False rules) } Eff ()
dummyGame = do
  if !('GameClock :- tick !yield)
     then endless
     else value ()
  drawGame
  dummyGame

main : IO ()
main = unSideEffect $ runInit {a = ()} {m = SideEffect} env dummyGame
  where env : Env SideEffect (SERPENT (Playing False (defaults serpentParams)))
        env = [startState, 'GameClock := (0, 0), Nothing, Red, defControlConfig]
--setLoop (loop {st = Game (Playing False (defaults serpentParams))} 0 ?play ?initState)
