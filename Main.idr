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

turn : Direction -> { [GAME (Playing False rules)] ==> {hitWall} [if hitWall then GAME (GameOver rules) else GAME (Playing False rules)] } Eff Bool
turn dir = call (Turn dir)

stepGame : InputState -> Float -> 
           { [GAME (Playing False rules), FPS 5] ==>
             {hitWall} [if hitWall then GAME (GameOver rules) else GAME (Playing False rules), FPS 5] 
           } Eff Bool
stepGame (MkI {button}) delta = do
  if !(tick delta)
     then turn (case button of
                    Just 'a' => TurnLeft
                    Just 'd' => TurnRight
                    _ => Straight)
     else pure False

-- stepGame : InputState -> Float -> Game (Playing False rules) -> Game (Playing False rules)
-- stepGame (MkI {button}) t (InGame xs walls food score univ) = runPure $ do
--   Turn (case button of
--          'w' => Straight
--          'a' => TurnLeft
--          'd' => TurnRight
--          _ => Straight)

main : IO ()
main = setLoop (loop {st = Game (Playing False (defaults serpentParams))} 0 ?play ?initState)
