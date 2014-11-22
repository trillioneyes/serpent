module CallbackStack

codata Loop : Type -> Type where
  MkLoop : IO (Int, st) -> Inf (st -> Loop st) -> Loop st

loop : (st -> IO st) -> (init : st) -> (interval : Int) -> Loop st
loop step init interval = MkLoop (return (interval, init)) iter where
  iter prev = loop step prev interval

setLoop : Loop st -> IO ()
setLoop {st} (MkLoop start f) = do
  (time, val) <- start
  setTimeout (\() => setLoop (f val)) time
 where setTimeout : (() -> IO ()) -> Int -> IO ()
       setTimeout f t =
         mkForeign (FFun "setTimeout(%0, %1)" [FFunction FUnit (FAny (IO ())), FInt] FUnit) f t
