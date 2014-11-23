-- This module defines a somewhat loose specification of the game at the type level.
-- Implementation details are avoided as much as possible.
module Spec
import Effects
import Data.List

data MenuInput : Type
updateFor : MenuInput -> Type

||| A phase is intended to categorize gamestates by what actions are available, i.e. two gamestates
||| should have the same phase if and only if they support the same kinds of player actions. This allows
||| us to state the specification without committing to a particular gamestate representation.
data Phase : Type where
  Playing : (paused : Bool) -> Phase
  MainMenu : Phase
  Menu : List MenuInput -> Phase
  GameOver : Phase

data Direction = Straight | TurnLeft | TurnRight

||| A data type of commands that can be given to a game. The data type is parameterized over the concrete
||| representation of the game state so that we don't need to define it here.
data Serpent : (Phase -> Type) -> Effect where

  Turn : Direction -> 
         { st (Playing False) ==> 
           {hitWall} if hitWall then st GameOver else st (Playing False) 
         } (Serpent st) Bool
  TogglePause : { st (Playing b) ==> st (Playing (not b)) } (Serpent st) ()
  Quit : { st (Playing True) ==> st MainMenu } (Serpent st) ()
  Restart : { st (Playing True) ==> st (Playing False) } (Serpent st) ()

  Update : Elem i inputs -> updateFor i ->
           { st (Menu inputs) } (Serpent st) ()
  FinishMenu : (save : Bool) -> { st (Menu inputs) ==> st MainMenu } (Serpent st) ()

  PlayAgain : { st GameOver ==> st (Playing False) } (Serpent st) ()
  Finished : { st GameOver ==> st MainMenu } (Serpent st) ()

  NewGame : { st MainMenu ==> st (Playing False) } (Serpent st) ()
  Randomize : { st MainMenu } (Serpent st) ()
  Reset : { st MainMenu } (Serpent st) ()
  Tweak : { st MainMenu ==> st (Menu ?params) } (Serpent st) ()
