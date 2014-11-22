module CallbackStack

codata Loop : Type -> Type where
  MkLoop : IO (Int, st) -> Inf (st -> Loop st) -> Loop st

loop : (st -> IO st) -> (init : st) -> (interval : Int) -> Loop st
loop step init interval = MkLoop (return (interval, init)) iter where
  iter prev = loop step prev interval
