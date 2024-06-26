import Data.Char
import Data.List
import System.Directory

type State = String
type TransitionFunc = (State, State, Char, Char, String)
data Machine = Machine { input :: String
                       , stack :: String
                       , states :: [State]
                       , start :: State
                       , final :: [State]
                       , transition :: [TransitionFunc]
                       } deriving (Show, Eq)
--Tokens used by parse
data Tokens = LBra | RBra | Comma | NL | Word String | Equals | Arrow
            | InputAlpha | StackAlpha | States | Start | Finals | Transitions
            | Err String | LPar | RPar | CharT Char | WordList [String]
            | TranFunc TransitionFunc | TranList [TransitionFunc] | StackStart
  deriving (Show, Eq)

getTranStates :: Machine -> [State]
getTranStates m = nub $ foldr(\x y -> (getTranStates' x) ++ y) [] (transition m)
getTranStates' :: TransitionFunc -> [State]
getTranStates' (s1, s2, _, _, _) = s1 : s2 : []

getTranInput :: Machine -> [Char]
getTranInput m = nub $ foldr(\x y -> (getTranInput' x) : y) [] (transition m)
getTranInput' :: TransitionFunc -> Char
getTranInput' (_, _, c, _, _) = c

getTranStack :: Machine -> [Char]
getTranStack m = nub $ foldr(\x y -> (getTranStack' x) ++ y) [] (transition m)
getTranStack' :: TransitionFunc -> [Char]
getTranStack' (_, _, _, c, w) = c:w

parse :: String -> [Tokens]
parse [] = []
parse x | take 10 x == "InputAlpha" = InputAlpha : parse (drop 10 x)
parse x | take 10 x == "StackAlpha" = StackAlpha : parse (drop 10 x)
parse x | take 6 x == "States" = States : parse (drop 6 x)
parse x | take 5 x == "Start" = Start : parse (drop 5 x)
parse x | take 6 x == "Finals" = Finals : parse (drop 6 x)
parse x | take 11 x == "Transitions" = Transitions : parse (drop 11 x) 
parse (' ':xs) = parse xs
parse ('=':xs) = Equals : parse xs
parse ('}':xs) = RBra : parse xs
parse ('{':xs) = LBra : parse xs
parse ('-':'>':xs) = Arrow : parse xs
parse ('\n':xs) = NL : parse xs
parse (',':xs) = Comma : parse xs
parse ('(':xs) = LPar : parse xs
parse (')':xs) = RPar : parse xs
parse ('_':xs) = CharT '\0' :parse xs --hmmm
parse (x:xs) | isAlphaNum x = CharT x : parse xs
parse x = [Err x]

sr :: [Tokens] -> [Tokens] -> [Tokens]
--TranFuncs
sr (CharT c1 : Comma : CharT c2 : Arrow : s) q = sr (CharT c1 : Arrow : CharT c2: Arrow: s) q 
sr (CharT c : Comma : Word w : Arrow : s) q = sr (CharT c : Arrow : Word w : Arrow : s) q
sr (RPar : Word w1 : Arrow : CharT c1 : Arrow 
    : CharT c2 : Arrow : Word w2 : Arrow : Word w3 
    : LPar : s) q 
    = sr (TranFunc (reverse w3, reverse w2, c2, c1, reverse w1) : s) q 
sr (RPar : CharT c1 : Arrow : CharT c2 : Arrow --incase last word is one character
    : CharT c3 : Arrow : Word w2 : Arrow : Word w3 
    : LPar : s) q 
    = sr (TranFunc (reverse w3, reverse w2, c3, c2, [c1]) : s) q 

--startLines
sr (LBra : Equals : InputAlpha : s) q = sr (Comma : Word [] : LBra : Equals : InputAlpha : s) q
sr (LBra : Equals : StackAlpha : s) q = sr (Comma : Word [] : LBra : Equals : StackAlpha : s) q
sr (LBra : Equals : States : s) q = sr (Comma : WordList [] : LBra : Equals : States : s) q
sr (LBra : Equals : Start : s) q = sr (Comma : Word [] : LBra : Equals : Start : s) q
sr (LBra : Equals : Finals : s) q = sr (Comma : WordList [] : LBra : Equals : Finals : s) q
sr (LBra : Equals : Transitions : s) q = sr (Comma : TranList [] : LBra : Equals : Transitions : s) q


--accumulate
sr (CharT c1 : CharT c2 : s) q = sr (Word (c1:c2:[]) : s) q
sr (CharT c1 : Word w : s) q = sr (Word (c1:w) : s) q 
sr (Comma : Word w : Comma : WordList wl : s) q = sr (Comma : WordList ((reverse w):wl) : s) q
sr (Comma : CharT c1 : Comma : CharT c2 : s) q = sr (Comma : Word (c1:c2:[]) : s) q
sr (Comma : CharT c1 : Comma : Word w : s) q = sr (Comma : Word (c1:w) : s) q
sr (Comma : TranFunc tf : Comma : TranList tl : s) q = sr (Comma : TranList (tf:tl) : s) q

--endSet
sr (RBra : Word w : Comma : WordList wl : s) q = sr (RBra : WordList ((reverse w):wl) : s) q
sr (RBra : CharT c1 : Comma : CharT c2 : s) q = sr (RBra : Word (c1:c2:[]) : s) q
sr (RBra : CharT c1 : Comma : Word w : s) q = sr (RBra : Word (c1:w) : s) q
sr (RBra : TranFunc tf : Comma : TranList tl : s) q = sr (RBra : TranList (tf:tl) : s) q
--endLines
sr (NL : RBra : Word w : LBra : Equals : InputAlpha : s) q = sr (Word (reverse w) : s) q 
sr (NL : RBra : Word w : LBra : Equals : StackAlpha : s) q = sr (Word (reverse w) : s) q
sr (NL : RBra : WordList wl : LBra : Equals : States : s) q = sr (WordList (reverse wl) : s) q
sr (NL : RBra : Word w : LBra : Equals : Start : s) q = sr (Word w : s) q
sr (NL : RBra : WordList wl : LBra : Equals : Finals : s) q = sr (WordList (reverse wl) : s) q
sr (NL : RBra : TranList tl : LBra : Equals : Transitions : s) q = sr (TranList (reverse tl) : s) q 
sr (RBra : TranList tl : LBra : Equals : Transitions : s) q = sr (TranList (reverse tl) : s) q 

--specialCases
--for start being only word no commmas
sr (NL : RBra : Word w1 : Comma : Word w2 : LBra : s) q = sr (NL : RBra : Word (reverse w1) : LBra : s) q 
--for single character words in wordlists
sr (Comma : CharT c : Comma : WordList wl : s) q = sr (Comma : WordList ([c]:wl) : s) q
sr (RBra : CharT c  : Comma  : WordList wl : s) q = sr (RBra : WordList ([c]:wl) : s) q 
--Incase states are one character 
sr (Arrow : CharT c : LPar : s) q = sr (Arrow : Word [c] : LPar : s) q
sr (CharT c : Arrow : Word w : LPar : s) q = sr (Word [c] : Arrow : Word w : LPar : s) q
--Ignore NL in sets
sr (Comma : NL : s) q = sr (Comma : s) q
sr (NL : Comma : s) q = sr (Comma : s) q
sr (NL : NL : s) q = sr (NL: s) q 

sr s [] = s
sr s (q:qs) = sr (q:s) qs

buildMachine :: String -> Machine
buildMachine s = case sr [] (parse s) of
                   (TranList tl : WordList wl1 : Word w1 : WordList wl2 : Word w2 : Word w3 : s) -> Machine w3 w2 wl2 w1 wl1 tl 
                   e -> error $ "Parse error: " ++ show e

checkMachine :: Machine -> Bool
checkMachine m = let startCheck = elem (start m) (states m)
                     finalCheck = foldr (\x y-> elem x (states m) && y) True (final m)
                     tranStateCheck = foldr (\x y-> elem x (states m) && y) True (getTranStates m)
                     inputCheck = foldr (\x y-> elem x ('\0':input m) && y) True (getTranInput m)
                     stackCheck = foldr (\x y-> elem x ('\0':stack m) && y) True (getTranStack m)
                  in startCheck && finalCheck && tranStateCheck && inputCheck && stackCheck

lookUpTran :: [TransitionFunc] -> State -> Char -> Char -> [TransitionFunc]
lookUpTran [] s c stk = []
lookUpTran ((s1,s2,c1,c2,w):xs) s c stk = if (s1 == s) && (c == c1) && (stk == c2) 
                                         then (s1,s2,c1,c2,w):(lookUpTran xs s c stk) 
                                         else lookUpTran xs s c stk


getMoveState :: TransitionFunc -> State
getMoveState (_,s2,_,_,_) = s2

getMoveStack :: TransitionFunc -> String
getMoveStack (_,_,_,_,(x:xs)) = if x == '\0' then [] else (x:xs)

runMachine :: State -> String -> [Char] -> Machine -> Bool
runMachine state [] (b:bx) m = let possible = lookUpTran (transition m) state '\0' b
                                    in foldl (\x y -> runMachine (getMoveState y) [] (getMoveStack y ++ bx) m || x) (elem state (final m)) possible
runMachine state (a:ax) (b:bx) m = let possible = lookUpTran (transition m) state a b
                                    in foldl (\x y -> runMachine (getMoveState y) ax (getMoveStack y ++ bx) m || x) False possible 
runMachine state (a:ax) [] m = let possible = lookUpTran (transition m) state a '\0'
                                    in foldl (\x y -> runMachine (getMoveState y) ax (getMoveStack y ++ []) m || x) False possible 
runMachine state [] [] m = let possible = lookUpTran (transition m) state '\0' '\0'
                             in if (elem state (final m)) then True else foldl (\x y -> runMachine (getMoveState y) [] (getMoveStack y ++ []) m || x) (elem state (final m)) possible

main :: IO ()
main = do
  putStr "Please enter filename: "
  str <- getLine
  real <- doesFileExist str
  if not real then do
    putStrLn "This file does not exists." >> main
  else do  
    contents <- readFile str
    let parseT = sr [] (parse contents)
    let machine = buildMachine contents
    if checkMachine machine then repl machine else do
      putStrLn "This is not a valid PDA. Please try a different PDA." >> main 
  
repl :: Machine -> IO ()  
repl machine = do
        input <- getLine
        case input of
          ".quit" -> return ()
          ".machine" -> main
          e -> do
            let outcome = runMachine (start machine) input "" machine
            case outcome of
              True -> putStrLn "The string was accepted." >> repl machine
              False -> putStrLn "The string was rejected." >> repl machine 