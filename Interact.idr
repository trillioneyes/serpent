module Interact
import Effects
import Data.List

data NonBlocking : Effect where
  Yield : { Maybe Float } NonBlocking Float

record SideEffect : Type -> Type where
  MkSideEffect : (unSideEffect : IO ()) -> SideEffect a

requestAnimationFrame : (Float -> IO ()) -> IO ()
requestAnimationFrame f =
  mkForeign (FFun "requestAnimationFrame(%0)" [FFunction FFloat (FAny (IO ()))] FUnit) f

instance Handler NonBlocking SideEffect where
  handle {a} Nothing Yield k = MkSideEffect $ do 
    requestAnimationFrame (\timeOffset => unSideEffect $ k 0 (Just timeOffset))
  handle {a} (Just prevFrame) Yield k = MkSideEffect $ do
    requestAnimationFrame (\timeOffset => unSideEffect $ k (timeOffset - prevFrame) (Just timeOffset))

instance Functor SideEffect where
  map {a} {b} f (MkSideEffect act) = MkSideEffect {a=b} act
instance Applicative SideEffect where
  pure _ = MkSideEffect $ return {m = IO} ()
  (MkSideEffect f) <$> (MkSideEffect act) = MkSideEffect $ f >>= const act
  

NONBLOCKING : EFFECT
NONBLOCKING = MkEff (Maybe Float) NonBlocking

yield : { [NONBLOCKING] } Eff Float
yield = call Yield

data Command = Forward | TurnLeft | TurnRight | Teleport | Reverse
             | FaceTop | FaceLeft | FaceRight | FaceBottom

data Key : Type where
  Alpha : Subset Char (so . isAlphaNum) -> Key
  LeftArrow : Key
  UpArrow : Key
  RightArrow : Key
  DownArrow : Key
  Escape : Key

getLastChar : IO (Maybe Key)
getLastChar = do
    code <- mkForeign (FFun "last_key" [] FInt)
    return (decode code)
  where decode : Int -> Maybe Key
        decode 37 = Just LeftArrow
        decode 38 = Just UpArrow
        decode 39 = Just RightArrow
        decode 40 = Just DownArrow
        decode _ = Nothing

data ControlConfig = MkConf (Key -> Maybe Command)

data ControlConfigError = Overlapping (List Command) Key

reportControls : ControlConfig -> List (Command, Maybe Key)
-- this should be a metavariable, but we want to be able to compile before it's done
reportControls _ = []

controls : List (Command, Key) -> Either ControlConfigError ControlConfig
controls _ = Left (Overlapping [] UpArrow)

data Controls : Effect where
  ReadCommand : { ControlConfig } Controls (Maybe Command)
  GetConfig : { ControlConfig } Controls (List (Command, Maybe Key))
  SetConfig : List (Command, Key) -> { ControlConfig } Controls (Maybe ControlConfigError)

instance Handler Controls SideEffect where
  handle (MkConf cfg) ReadCommand k = MkSideEffect $ do
    lastChar <- getLastChar
    unSideEffect $ k (lastChar >>= cfg) (MkConf cfg)
  handle cfg GetConfig k = k (reportControls cfg) cfg
  handle cfg (SetConfig mapping) k = case controls mapping of
    Left err => k (Just err) cfg
    Right newCfg => k Nothing newCfg

defControlConfig : ControlConfig
defControlConfig = MkConf decode where
  decode LeftArrow = Just FaceLeft
  decode RightArrow = Just FaceRight
  decode UpArrow = Just FaceTop
  decode DownArrow = Just FaceBottom
  decode _ = Nothing

CONTROLS : EFFECT
CONTROLS = MkEff ControlConfig Controls

readCommand : { [CONTROLS] } Eff (Maybe Command)
readCommand = call ReadCommand

getConfig : { [CONTROLS] } Eff (List (Command, Maybe Key))
getConfig = call GetConfig

setConfig : List (Command, Key) -> { [CONTROLS] } Eff (Maybe ControlConfigError)
setConfig mapping = call (SetConfig mapping)
