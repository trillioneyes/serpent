module Draw
import GameState
import Interact

canvasWidth : IO Int
canvasWidth = mkForeign (FFun "game_width()" [] FInt)
canvasHeight : IO Int
canvasHeight = mkForeign (FFun "game_height()" [] FInt)

convert : (Int, Int, Int, Int) -> IO (Int, Int, Int, Int)
convert (l, r, t, b) = do
  w <- canvasWidth
  h <- canvasHeight
  return $ assert_total ((w `div` 2) + l, (w `div` 2) + r, (h `div` 2) + t, (h `div` 2) + b)

drawRect : (left : Int) -> (right : Int) -> (top : Int) -> (bottom : Int) -> IO ()
drawRect l r t b = mkForeign (FFun "context.fillRect(%0, %1, %2, %3)" [FInt, FInt, FInt, FInt] FUnit)
                         l t (r - l) (b - t)

boundingRect : TailSegment -> (Int, Int, Int, Int)
boundingRect (Seg ToLeft w (headX, headY)) = (headX, headX + cast w, headY - 5, headY + 5)
boundingRect (Seg ToRight w (headX, headY)) = (headX - cast w, headX, headY - 5, headY + 5)
boundingRect (Seg ToTop h (headX, headY)) = (headX - 5, headX + 5, headY, headY + cast h)
boundingRect (Seg ToBottom h (headX, headY)) = (headX - 5, headX + 5, headY - cast h, headY)

data Color = Brown | Green | Red | Yellow

instance Eq Color where
  Brown == Brown = True
  Green == Green = True
  Red == Red = True
  Yellow == Yellow = True
  _ == _ = False

setColor : Color -> IO ()
setColor color = mkForeign (FFun "context.fillStyle = %0" [FString] FUnit) name
  where name = case color of
                    Brown => "brown"
                    Green => "green"
                    Red => "red"
                    Yellow => "yellow"

clearCanvas : IO ()
clearCanvas = mkForeign (FFun "context.clearRect(0, 0, canvas.width, canvas.height)" [] FUnit)

data Canvas : Effect where
  Rect : (left : Int) -> (right : Int) -> (top : Int) -> (bottom : Int) -> Color ->
         { Color } Canvas ()
  Clear : { Color } Canvas ()

instance Handler Canvas SideEffect where
  handle oldC (Rect l r t b c) k =
    MkSideEffect {a = ()}
                 (if oldC == c then drawRect l r t b
                               else do setColor c
                                       drawRect l r t b) $> 
    k () c
  handle c Clear k = MkSideEffect {a = ()} clearCanvas $> k () c

CANVAS : EFFECT
CANVAS = MkEff Color Canvas

rect : Int -> Int -> Int -> Int -> Color -> { [CANVAS] } Eff ()
rect l r t b c = call (Rect l r t b c)

clear : { [CANVAS] } Eff ()
clear = call Clear

drawSegment : TailSegment -> { [CANVAS] } Eff ()
drawSegment seg = do
  let (l, r, t, b) = boundingRect seg
  rect l r t b Green

drawSnake : Snake -> { [CANVAS] } Eff ()
drawSnake [] = value ()
drawSnake (seg::segs) = do
  drawSegment seg
  drawSnake segs
