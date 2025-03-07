{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# OPTIONS_GNC -Wall #-}
------------------import--------------------
import System.IO
import System.Timeout
import Control.Monad
import Data.Array
import Data.Ord
import Control.Applicative
import Control.Monad
import Data.List
import Data.Maybe
import Control.Arrow
import Data.List.Split
import Debug.Trace
import Data.Set (Set)
import qualified Data.Set as S
--------------------data---------------------------
type Pos = (Int,Int)
type Arch = Array Pos Bool
newtype Quadrant = Quadrant Int deriving Show

dist:: Pos -> Pos -> Int
dist (a,b) (c,d) = abs (c-a) + abs (d-b)

posIn :: Pos -> Quadrant -> Bool
posIn (y,x) (Quadrant q) = q == 1 + 3*i + j
    where i= y `div` 5
          j= x `div` 5

data Info = Info { islands :: Arch
                 , prevTrail :: Arch
                 , prevOTrail :: [Either Quadrant Heading]
                 , prevOCover :: Set Pos
                 }

data Heading = N | S | E | W deriving (Show, Read, Bounded, Enum) -- north | south | east | west       

data Order = SURFACE Int  
           | MOVE Heading  -- MOVE N
           | TORPEDO Int Int     -- TORPEDO 3 5
           deriving (Show,Read)

isMove :: Order -> Maybe Heading
isMove (MOVE h) = Just h
isMove _ = Nothing --return that heading, otherwise return nothing

isSurface :: Order -> Maybe Quadrant
isSurface (SURFACE q) = Just (Quadrant q)
isSurface _ = Nothing-- return quadrant, otherwise return nothing

allDirs :: [Heading]
allDirs = [minBound..maxBound]

move :: Pos -> Heading -> Pos
move(y,x) N = (y-1,x) -- if it goes north, decrease y by -1.
move(y,x) S = (y+1,x) -- if it goes south, increase y by 1.
move(y,x) E = (y,x+1) -- if it goes east, decrease x by 1.
move(y,x) W = (y,x-1)  -- If it goes west, decrease x by -1.

oppMove :: Arch -> Pos -> Either Quadrant Heading -> Maybe Pos
oppMove _ pos (Left q) = guard (pos `posIn` q) *> Just pos
oppMove arch pos (Right h) = guard (inRange ((0,0),(14,14)) pos') *>
                             guard (not (arch ! pos) ) *>
                             Just pos'
    where pos' = move pos h 
--------------breadth-first search-----------------------
r:: (Pos,Pos)
r = ((0,0),(14,14))   
bfs :: Arch -> Pos -> Set Pos --breadth-first search
bfs arch p0 = S.fromList $ go S.empty [(p0,0)] where
  go :: Set Pos -> [(Pos, Int)] -> [Pos]
  go _ [] = []
  go cl ((p,d):q) | not (inRange r p) = go cl q
                  | arch ! p          = go cl q
                  | d > 4             = go cl' q
                  | otherwise         = p : go cl' (q ++ q')
    where cl' = p `S.insert` cl  
          q' = map (flip (,) (d-1) . move p) allDirs
------------------main------------------------
main :: IO ()
main = do
  hSetBuffering stdout LineBuffering -- DO NOT REMOVE

  input_line <- getLine
  let input = words input_line
  let _width = read (input!!0) :: Int
  let height@15 = read (input!!1) :: Int
  let _myid = read (input!!2) :: Int

  islands <- listArray ((0,0),(14,14)) . map (== 'x') . concat <$> -- list of islands
                 replicateM height getLine

    -- Write action to stdout
  let Just (startY,startX) = fst <$> find (not .snd) (assocs islands) -- starting position - we need to know it is not an island.
  putStrLn $ show startX ++ " " ++ show startY

  let trail0 = islands


  gameTurn Info { islands = islands
                , prevTrail = trail0 
                , prevOTrail  = error "no opp. trail before first trun"
                , prevOCover = S.fromList $ map fst $ filter (not .snd ) $ assocs islands
                } --prevOCover is possible opponent position
-------------------gameTurn---------------------
gameTurn :: Info -> IO ()   
gameTurn info@Info{..} = do  -- recordwildcards
  [x, y, _mylife, _opplife  -- x and y indicate our current position 
    ,torpedocooldown, _sonarcooldown
    ,_silencecooldown, _minecooldown ] <- map read . words <$> getLine
  _sonarresult <- getLine  --this underscores variables unused for now
  opponentOrderRaw <- getLine
  let myPos = (y,x) :: Pos

     -- first turn
  let firstTurn = opponentOrderRaw == "NA"

     -- parse opponet decison
  let opponentOrders = map read $ wordsBy (== '|') opponentOrderRaw -- list of orders
      oMove = listToMaybe $ mapMaybe isMove opponentOrders
      oSurface = listToMaybe $ mapMaybe isSurface opponentOrders
      Just oDecision = (Right <$> oMove) <|> (Left <$> oSurface) --moving or not moving
      opponentTrail | firstTurn = []
                    | otherwise = oDecision : prevOTrail

     -- opponent cover update
  let opponentCover   
         | firstTurn = prevOCover
         | otherwise = S.fromList $ 
                       mapMaybe (flip (oppMove islands) oDecision) $
                       S.toList prevOCover

 -- update trail
  let trail = prevTrail // [((y,x),True)]  --the trail is a current position that we don't want to go again

  -- finding around us for a possible move
  let reachableDests = filter (inRange (bounds islands) . snd ) $ -- it is a set of a position around my current pos
                        map (id &&& move (y,x)) allDirs  
      possibleDests = filter (not . (trail !) . snd) reachableDests --it is a thing that hasn't been to between two surfaces.
      selectedDest = fst <$> listToMaybe possibleDests
  
    --it's for taking damage to the opponent using torpedo
  let torpedoCover = bfs islands myPos
      damageCover = opponentCover `S.intersection` torpedoCover :: Set Pos
      torpedoShootPos = listToMaybe $ sortBy (comparing (Down . dist myPos)) (S.toList damageCover) :: Maybe Pos
      torpedoAction = fmap (\(ty,tx) -> "TORPEDO" ++ show tx ++ " " ++ show ty) torpedoShootPos :: Maybe String
  
  let (moveAction,newTrail) = case selectedDest of
          Nothing -> ("SURFACE", islands)
          Just h -> ("MOVE" ++ show h ++ "TORPEDO",trail)
  putStrLn $ intercalate "|" (moveAction : maybeToList torpedoAction)

  gameTurn info { prevTrail = newTrail 
                ,prevOTrail = opponentTrail
                ,prevOCover = opponentCover
                }
