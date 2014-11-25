-- This module defines a somewhat loose specification of the game at the type level.
-- Implementation details are avoided as much as possible.
module Spec
import Effects
import Data.List

||| A data type for describing parameter input fields. FloatBox and NatBox represent numbers,
||| Toggle represents an on/off button with additional options for the on case, and Options
||| represents a set of mutually exclusive possibilities. The first String field is always a
||| display name. The final field is a default value.
data MenuInput : Type where
  FloatBox : String -> Float -> MenuInput
  NatBox : String -> Nat -> MenuInput
  Toggle : String -> String -> String -> List MenuInput -> Bool -> MenuInput
  Options : String -> (opts : List String) -> Elem choice opts -> MenuInput

mutual
    valueFor : MenuInput -> Type
    valueFor (FloatBox _ _) = Float
    valueFor (NatBox _ _) = Nat
    valueFor (Toggle _ _ _ extra _) =
      assert_total (toggle : Bool ** if toggle then valuesFor extra else ())
    valueFor (Options _ names _) = (choice ** Elem choice names)

    valuesFor : List MenuInput -> Type
    valuesFor (i :: inputs) = (valueFor i, valuesFor inputs)
    valuesFor [] = ()

||| updateFor is like 'valueFor', but 
data updateFor : MenuInput -> Type where
  Exact : valueFor i -> updateFor i
  Decrease : Nat -> updateFor (NatBox name def)
  Increase : Nat -> updateFor (NatBox name def)
  Add : Float -> updateFor (FloatBox name def)
  Switch : updateFor (Toggle name off on extras def)

updateParam : (vals : valuesFor inputs) -> Elem i inputs -> updateFor i -> valuesFor inputs

mutator : String -> List MenuInput -> MenuInput
mutator name opts = Toggle name "off" "on" opts False
opts : String -> String -> List String -> MenuInput
opts name def alts = Options name (def :: alts) Here

serpentParams : List MenuInput
serpentParams = [
  mutator "Big head" [NatBox "Radius" 1],
  mutator "Corner walls" [],
  mutator "Random walls" [
    NatBox "Amount" 5,
    mutator "Periodic" [FloatBox "Interval" 10],
    mutator "Random amount" [FloatBox "Deviation" 1]
  ],
  mutator "Extra growth" [
    NatBox "Amount" 1,
    mutator "Random amount" [FloatBox "Deviation" 0.2]
  ],
  mutator "Moving food" [opts "Behavior" "Flee player" ["Move randomly"]],
  mutator "Phasing food" [
    FloatBox "Period" 1.5,
    mutator "Random duration" [FloatBox "Deviation" 0.05],
    opts "While phased..." "Vanish" ["Turn to stone"]
  ]
  -- This isn't done yet... spend some not-working time entering the parameters
  -- because this is super boring and annoying
]

Ruleset : Type
Ruleset = valuesFor serpentParams

||| A phase is intended to categorize gamestates by what actions are available, i.e. two gamestates
||| should have the same phase if and only if they support the same kinds of player actions. This allows
||| us to state the specification without committing to a particular gamestate representation.
data Phase : Type where
  Playing : (paused : Bool) -> Ruleset -> Phase
  MainMenu : Ruleset -> Phase
  Menu : List MenuInput -> Ruleset -> Phase
  GameOver : Ruleset -> Phase

data Direction = Straight | TurnLeft | TurnRight

||| A data type of commands that can be given to a game. The data type is parameterized over the concrete
||| representation of the game state so that we don't need to define it here.
data Serpent : (Phase -> Type) -> Effect where

  Turn : Direction -> 
         { st (Playing False rules) ==> 
           {hitWall} st (if hitWall then GameOver rules else Playing False rules)
         } (Serpent st) Bool
  TogglePause : { st (Playing b rules) ==> st (Playing (not b) rules) } (Serpent st) ()
  Quit : { st (Playing True rules) ==> st (MainMenu rules) } (Serpent st) ()
  Restart : st (Playing False rules) -> 
            { st (Playing True rules) ==> st (Playing False rules) } (Serpent st) ()

  Update : Elem i inputs -> updateFor i ->
           { st (Menu inputs rules) } (Serpent st) (valueFor i)
  ExitMenu : { st (Menu inputs rules) ==> st (MainMenu rules) } (Serpent st) ()
  SaveMenu : { st (Menu snakeParams rules) ==>
               {valid} case valid of
                 Nothing => st (Menu snakeParams rules)
                 Just new => st (MainMenu new)
             } (Serpent st) (Maybe Ruleset)

  PlayAgain : st (Playing False rules) ->
              { st (GameOver rules) ==> st (Playing False rules) } (Serpent st) ()
  Finished : { st (GameOver rules) ==> st (MainMenu rules) } (Serpent st) ()

  NewGame : st (Playing False rules) -> 
            { st (MainMenu rules) ==> st (Playing False rules) } (Serpent st) ()
  Randomize : Ruleset -> { st (MainMenu rules) } (Serpent st) Ruleset
  Reset : { st (MainMenu rules) } (Serpent st) Ruleset
  Tweak : { st (MainMenu rules) ==> st (Menu serpentParams rules) } (Serpent st) ()
