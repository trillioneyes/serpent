module Main
import CallbackStack

announceDec : Int -> IO Int
announceDec 0 = do
  putStr "Finished counting down!"
  return 0
announceDec x = do
  putStr (show x)
  return (x-1)

main : IO ()
main = setLoop (loop announceDec 10 1000)
