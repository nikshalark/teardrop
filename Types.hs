{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE OverloadedRecordDot #-}

module Types where

import           System.Console.ANSI
import           Data.Serialize as S
import qualified Data.Vector as V
import qualified Data.Map.Strict as M

data Statelike s a = Statelike s (M.Map s a) deriving (Eq, Show) 

data Global = Global
  { txSelect :: Statelike Page (Statelike Int Char)
  , fgSelect :: Statelike Int FGColor
  , bgSelect :: Statelike Int BGColor
  , relCursor :: RelCursor
  , mode :: (Mode1, Mode2)
  } deriving (Eq, Show)

collapse :: Ord s => Statelike s a -> a
collapse sl = stripD sl M.! stripI sl

pack :: Global -> Cell
pack global = 
  (,) (toSGR $ FullColor (collapse global.fgSelect) (collapse global.bgSelect)) 
      (collapse . collapse $ global.txSelect) -- coolest line of code ive ever written

stripIndexFromStatelike :: Statelike s a -> s
stripIndexFromStatelike (Statelike s a) = s -- remembering const functor fondly

stripDataFromStatelike :: Statelike s a -> M.Map s a
stripDataFromStatelike (Statelike s a) = a

stripI = stripIndexFromStatelike
stripD = stripDataFromStatelike

data Page = Latin1 | LatinSupp | LatinExtA | Box | Block | Braille deriving (Eq, Bounded, Enum, Show, Ord)

data Mode1 = Normal | Extended | Paint | Erase | Replace deriving (Eq, Show)
data Mode2 = Stamp | Text | Line | Polygon | PolyFill deriving (Eq, Show)

type Image = V.Vector (V.Vector Cell)  

type Cell = ([SGR], Char)  

type RelCursor = (Int, Int)

lift' :: M.Map s a -> Statelike s a
lift' m = Statelike (fst $ M.findMin m) m

next :: (Ord s, Enum s, Bounded s, Eq a) => (Statelike s a) -> (Statelike s a)
next sl@(Statelike s a) = 
  if (||) (s == maxBound) (M.lookup (succ s) a == Nothing) 
  then sl 
  else Statelike (succ s) a

prev :: (Ord s, Enum s, Bounded s, Eq a) => (Statelike s a) -> (Statelike s a)
prev sl@(Statelike s a) = 
  if (||) (s == minBound) (M.lookup (pred s) a == Nothing)
  then sl 
  else Statelike (pred s) a

-- lazy evaluation makes this work, || shortcircuits if the first argument is false
-- so something like (succ maxBound) will not occur

class Colorlike a where
        toSGR :: a -> [SGR]

class Strippable a where
        strip :: a -> (ColorIntensity, Color)

data FGColor = FGColor !ColorIntensity !Color deriving (Eq, Show)

instance Colorlike FGColor where
        toSGR (FGColor a b) = [SetColor Foreground a b]

instance Strippable FGColor where
        strip (FGColor a b) = (a,b)

data BGColor = BGColor !ColorIntensity !Color deriving (Eq, Show)

instance Colorlike BGColor where
        toSGR (BGColor a b) = [SetColor Background a b]

instance Strippable BGColor where
        strip (BGColor a b) = (a,b)

data FullColor = FullColor FGColor BGColor

instance Colorlike FullColor where
        toSGR (FullColor a b) = toSGR a ++ toSGR b

instance Colorlike SGR where
        toSGR a = [a]

instance Colorlike [SGR] where
        toSGR = id

instance Serialize SGR where
  get = read <$> S.get
  put = S.put . show
