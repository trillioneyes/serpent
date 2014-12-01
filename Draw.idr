module Draw
import GameState
import Interact

canvasWidth : IO Int
canvasWidth = mkForeign (FFun "game_width()" [] FInt)
canvasHeight : IO Int
canvasHeight = mkForeign (FFun "game_height()" [] FInt)

drawRect : (left : Int) -> (right : Int) -> (top : Int) -> (bottom : Int) -> IO ()
drawRect l r t b = mkForeign (FFun "context.fillRect(%0, %1, %2, %3)" [FInt, FInt, FInt, FInt] FUnit)
                         l t (r - l) (b - t)

boundingRect : TailSegment -> (Int, Int, Int, Int)
boundingRect (Seg ToLeft w (headX, headY)) = (headX, headX + cast w, headY, headY + 1)
boundingRect (Seg ToRight w (headX, headY)) = (headX - cast w, headX, headY, headY + 1)
boundingRect (Seg ToTop h (headX, headY)) = (headX, headX + 1, headY, headY + cast h)
boundingRect (Seg ToBottom h (headX, headY)) = (headX, headX + 1, headY - cast h, headY)

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
  GetSize : { Color } Canvas (Int, Int)

instance Handler Canvas SideEffect where
  handle oldC (Rect l r t b c) k =
    MkSideEffect {a = ()}
                 (if oldC == c then drawRect l r t b
                               else do setColor c
                                       drawRect l r t b) $> 
    k () c
  handle c Clear k = MkSideEffect {a = ()} clearCanvas $> k () c
  handle c GetSize k = MkSideEffect $ do
    w <- canvasWidth
    h <- canvasHeight
    unSideEffect (k (w, h) c)

CANVAS : EFFECT
CANVAS = MkEff Color Canvas

rect : Int -> Int -> Int -> Int -> Color -> { [CANVAS] } Eff ()
rect l r t b c = call (Rect l r t b c)

clear : { [CANVAS] } Eff ()
clear = call Clear

getSize : { [CANVAS] } Eff (Int, Int)
getSize = call GetSize

translate : (Int, Int, Int, Int) -> { [CANVAS] } Eff (Int, Int, Int, Int)
translate (l, r, t, b) = do
  (w, h) <- getSize
  let newRect = assert_total ((w `div` 2) + l, (w `div` 2) + r, (h `div` 2) + t, (h `div` 2) + b)
  return newRect

scale : (Int, Int) -> (Int, Int, Int, Int) -> (Int, Int, Int, Int)
scale (dx, dy) (l, r, t, b) = (l * dx, r * dx, t * dy, b * dy)

convert : (Int, Int, Int, Int) -> { [CANVAS] } Eff (Int, Int, Int, Int)
convert r = translate (scale (5, 5) r)

drawSegment : TailSegment -> { [CANVAS] } Eff ()
drawSegment seg = do
  (l, r, t, b) <- convert (boundingRect seg)
  rect l r t b Green

drawSnake : Snake -> { [CANVAS] } Eff ()
drawSnake [] = value ()
drawSnake (seg::segs) = do
  drawSegment seg
  drawSnake segs
