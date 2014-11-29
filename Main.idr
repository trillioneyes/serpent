module Main
import CallbackStack
import GameState
import Draw
import Interact
import Effects

%include javascript "helper.js"

record InputState : Type where
  MkI : {button : Maybe Char} -> InputState

data Frames : Nat -> Effect where
  Tick : (millis : Float) -> { (Float, Float) } (Frames fps) Bool

instance Handler (Frames fps) m where
  handle (last, elapsed) (Tick delta) k =
      k ticked (if ticked then nextFrame else last, elapsed + delta)
    where nextFrame = last + 1/cast (cast {to=Int} fps)
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

endless : { [GAME (Playing False rules)] } Eff ()
endless = do
  hit <- turn Straight
  case hit of
    True => playAgain startState
    False => value ()

dummyGame : { [GAME (Playing False rules), GameClock, NONBLOCKING] } Eff ()
dummyGame = do
  if !('GameClock :- tick !yield)
     then endless
     else value ()
  dummyGame

main : IO ()
main = unSideEffect $ runInit {a = ()} {m = SideEffect} env dummyGame
  where env : Env SideEffect [GAME (Playing False (defaults serpentParams)), GameClock, NONBLOCKING]
        env = [startState, 'GameClock := (0, 0), ()]
--setLoop (loop {st = Game (Playing False (defaults serpentParams))} 0 ?play ?initState)
