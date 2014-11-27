module Main
import CallbackStack
import GameState
import Effects

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

GAME : Phase -> EFFECT
GAME ph = MkEff (Game ph) (Serpent Game)

tick : Float -> { [FPS n] } Eff Bool
tick {n} delta = call (Tick delta)

turn : (dir : Direction) -> 
       { [GAME (Playing False rules)] ==>
         {hitWall} [GAME (if hitWall then GameOver rules else (Playing False rules))] 
       } Eff Bool
turn dir = call (Turn dir)

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

main : IO ()
main = setLoop (loop {st = Game (Playing False (defaults serpentParams))} 0 ?play ?initState)
