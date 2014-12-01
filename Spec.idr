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
      assert_total (Maybe (valuesFor extra))
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

getValue : Elem i inputs -> valuesFor inputs -> valueFor i
getValue Here (a, b) = a
getValue (There p) (a, b) = getValue p b

defaults : (inputs : List MenuInput) -> valuesFor inputs
defaults [] = ()
defaults (i :: inputs) = (assert_total def, defaults inputs) where
  def = case i of
    FloatBox name d => d
    NatBox name d => d
    Toggle name off on extra True => Just (defaults extra)
    Toggle name off on extra False => Nothing
    Options {choice} name opts d => (choice ** d)

updateParam : (vals : valuesFor inputs) -> Elem i inputs -> updateFor i -> valuesFor inputs
updateParam (a, b) Here (Exact x) = (x, b)
updateParam (a, b) Here (Decrease k) = (a - k, b)
updateParam (a, b) Here (Increase k) = (a + k, b)
updateParam (a, b) Here (Add x) = (a + x, b)
updateParam (Just _, b) Here Switch = (Nothing, b)
updateParam {i=Toggle _ _ _ i _} (Nothing, b) Here Switch = (Just (defaults i), b)
updateParam (a, b) (There x) update = (a, updateParam b x update)

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
  SaveMenu : { st (Menu serpentParams rules) ==>
               {valid} case valid of
                 Nothing => st (Menu serpentParams rules)
                 Just new => st (MainMenu new)
             } (Serpent st) (Maybe Ruleset)

  PlayAgain : st (Playing False rules) ->
              { st (GameOver rules) ==> st (Playing False rules) } (Serpent st) ()
  Finished : { st (GameOver rules) ==> st (MainMenu rules) } (Serpent st) ()

  NewGame : st (Playing False rules) -> 
            { st (MainMenu rules) ==> st (Playing False rules) } (Serpent st) ()
  Randomize : (new : Ruleset) -> { st (MainMenu rules) ==> st (MainMenu new) } (Serpent st) Ruleset
  Reset : { st (MainMenu rules) ==> st (MainMenu (defaults serpentParams)) } (Serpent st) ()
  Tweak : { st (MainMenu rules) ==> st (Menu serpentParams rules) } (Serpent st) ()

  Get : { st ph } (Serpent st) (st ph)

GameEff : (Phase -> Type) -> Phase -> EFFECT
GameEff st ph = MkEff (st ph) (Serpent st)

turn : Direction -> 
       { [GameEff st (Playing False rules)] 
         ==> {hitWall} 
         [GameEff st (if hitWall then GameOver rules else Playing False rules)]
       } Eff Bool
turn {st} {rules} d = call (Turn {st} {rules} d)

togglePause : { [GameEff st (Playing isPaused rules)] ==> [GameEff st (Playing (not isPaused) rules)] }
              Eff ()
togglePause {isPaused} {st} {rules} = call (TogglePause {st} {rules} {b = isPaused})

quit : { [GameEff st (Playing True rules)] ==> [GameEff st (MainMenu rules)] } Eff ()
quit {st} {rules} = call $ Quit {st} {rules}

restart : st (Playing False rules) ->
          { [GameEff st (Playing True rules)] ==> [GameEff st (Playing False rules)] } Eff ()
restart {st} {rules} newGame = call (Restart {st} {rules} newGame)

update : Elem i inputs -> updateFor i ->
         { [GameEff st (Menu inputs rules)] } Eff (valueFor i)
update {i} {inputs} {st} {rules} prf upd = call (Update {i} {inputs} {rules} {st} prf upd)

exitMenu : { [GameEff st (Menu inputs rules)] ==> [GameEff st (MainMenu rules)] } Eff ()
exitMenu {st} {inputs} {rules} = call (ExitMenu {st} {inputs} {rules})

saveMenu : { [GameEff st (Menu serpentParams rules)]
             ==> {valid}
             case valid of
               Nothing => [GameEff st (Menu serpentParams rules)]
               Just new => [GameEff st (MainMenu new)]
           } Eff (Maybe Ruleset)
saveMenu {st} {rules} = call (SaveMenu {st} {rules})

playAgain : st (Playing False rules) -> { [GameEff st (GameOver rules)] ==> [GameEff st (Playing False rules)] } Eff ()
playAgain {st} {rules} newGame = call (PlayAgain {st} {rules} newGame)

finished : { [GameEff st (GameOver rules)] ==> [GameEff st (MainMenu rules)] } Eff ()
finished {st} {rules} = call (Finished {st} {rules})

newGame : st (Playing False rules) -> 
          { [GameEff st (MainMenu rules)] ==> [GameEff st (Playing False rules)] } Eff ()
newGame {st} {rules} new = call (NewGame {st} {rules} new)

randomize : (new : Ruleset) -> { [GameEff st (MainMenu rules)] ==> [GameEff st (MainMenu new)] } Eff Ruleset
randomize {st} {rules} new = call (Randomize {st} {rules} new)

tweak : { [GameEff st (MainMenu rules)] ==> [GameEff st (Menu serpentParams rules)] } Eff ()
tweak {st} {rules} = call (Tweak {st} {rules})
 
get : { [GameEff st ph] } Eff (st ph)
get {st} {ph} = call (Get {st} {ph})
