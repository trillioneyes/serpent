module Draw
import GameState

rect : Coord -> (w : Nat) -> (h : Nat) -> IO ()
rect (centerX, centerY) w h =
    mkForeign (FFun "context.fillRect(%0, %1, %2, %3)" [FInt, FInt, FInt, FInt] FUnit)
              tlx tly (2*cast w) (2*cast h)
  where tlx = centerX - cast w
        tly = centerY - cast h

boundingRect : TailSegment -> (Coord, Nat, Nat)
boundingRect (Seg ToLeft l (headX, headY)) = ((cast (S l `div` 2) + headX, headY), S l `div` 2, 10)
boundingRect (Seg ToRight l (headX, headY)) = ((headX - cast (S l `div` 2), headY), S l `div` 2, 10)
boundingRect (Seg ToTop h (headX, headY)) = ((headX, headY + cast (S h `div` 2)), 10, S h `div` 2)
boundingRect (Seg ToBottom h (headX, headY)) = ((headX, headY - cast (S h `div` 2)), 10, S h `div` 2)

drawSegment : TailSegment -> IO ()
drawSegment seg = let (c, w, h) = boundingRect seg in rect c w h

drawSnake : Snake -> IO ()
drawSnake = traverse_ drawSegment

setColor : String -> IO ()
setColor name = mkForeign (FFun "context.fillStyle = %0" [FString] FUnit) name

drawGame : Game (Playing False rules) -> IO ()
drawGame (InGame snake walls food score univ) = do
  setColor "green"
  drawSnake snake
  setColor "brown"
  traverse_ rectCell walls
  setColor "red"
  traverse_ rectCell food
 where rectCell : Coord -> IO ()
       rectCell c = rect c 10 10

data Color = Brown | Green | Red | Yellow
