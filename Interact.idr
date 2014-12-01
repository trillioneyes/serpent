module Interact
import Effects

data NonBlocking : Effect where
  Yield : { () } NonBlocking Float

record SideEffect : Type -> Type where
  MkSideEffect : (unSideEffect : IO ()) -> SideEffect a

requestAnimationFrame : (Float -> IO ()) -> IO ()
requestAnimationFrame f =
  mkForeign (FFun "requestAnimationFrame(%0)" [FFunction FFloat (FAny (IO ()))] FUnit) f

instance Handler NonBlocking SideEffect where
  handle {a} () Yield k = MkSideEffect $ do 
    requestAnimationFrame (\delta => unSideEffect $ k delta ())

instance Functor SideEffect where
  map {a} {b} f (MkSideEffect act) = MkSideEffect {a=b} act
instance Applicative SideEffect where
  pure _ = MkSideEffect $ return {m = IO} ()
  (MkSideEffect f) <$> (MkSideEffect act) = MkSideEffect $ f >>= const act
  

NONBLOCKING : EFFECT
NONBLOCKING = MkEff () NonBlocking

yield : { [NONBLOCKING] } Eff Float
yield = call Yield
