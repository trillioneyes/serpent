module CallbackStack

codata Loop : Type -> Type where
  MkLoop : IO st -> Inf (st -> Float -> Loop st) -> Loop st

loop : Float -> (Float -> st -> IO st) -> (init : st) -> Loop st
loop t step init = MkLoop (step t init) iter where
  iter prev time = loop time step prev

setLoop : Loop st -> IO ()
setLoop {st} (MkLoop start f) = do
  val <- start
  setTimeout (\t => setLoop (f val t))
 where setTimeout : (Float -> IO ()) -> IO ()
       setTimeout f =
         mkForeign (FFun "requestAnimationFrame(%0)" [FFunction FFloat (FAny (IO ()))] FUnit) f
