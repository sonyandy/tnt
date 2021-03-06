{-# LANGUAGE
    FlexibleContexts
  , FlexibleInstances
  , GeneralizedNewtypeDeriving
  , MultiParamTypeClasses
  , RecordWildCards
  , StandaloneDeriving
  , TypeSynonymInstances
  , UndecidableInstances #-}
module Language.TNT.Scope
       ( ScopeT
       , runScopeT
       , define
       , lookup
       , nest
       ) where

import Control.Applicative
import Control.Comonad
import Control.Monad.Error
import Control.Monad.State

import Data.Map (Map)
import qualified Data.Map as Map

import Language.TNT.Location
import Language.TNT.Name
import Language.TNT.Unique

import Prelude hiding (lookup)

data S = S
         { currentScope :: Map String Name
         , scopeChain :: [Map String Name]
         }

newtype ScopeT m a = ScopeT
                     { unScopeT :: StateT S (UniqueT m) a
                     } deriving ( Functor
                                , Applicative
                                , Monad
                                )

deriving instance MonadError e m => MonadError e (ScopeT m)

instance MonadState s m => MonadState s (ScopeT m) where
  get = ScopeT . lift . lift $ get
  put = ScopeT . lift . lift . put

instance MonadTrans ScopeT where
  lift = ScopeT . lift . lift

getCurrentScope :: Monad m => ScopeT m (Map String Name)
getCurrentScope = ScopeT $ do
  S {..} <- get
  return currentScope

putCurrentScope :: Monad m => Map String Name -> ScopeT m ()
putCurrentScope m = ScopeT $ do
  s@S {..} <- get
  put s { currentScope = m }

getScopeChain :: Monad m => ScopeT m [Map String Name]
getScopeChain = ScopeT $ do
  S {..} <- get
  return scopeChain

runScopeT :: Monad m => ScopeT m a -> m a
runScopeT (ScopeT m) = runUniqueT $ evalStateT m s
  where
    s = S { currentScope = Map.empty
          , scopeChain = []
          }

define :: MonadError (Located String) m => Located String -> ScopeT m Name
define w = do
  m <- getCurrentScope
  case Map.lookup s m of
    Nothing -> do
      x <- newName s
      let m' = Map.insert s x m
      putCurrentScope m'
      return x
    Just _ ->
      throwError $ ("scope error: " ++ show s ++ " already defined") <$ w
  where
    s = extract w

newName :: Monad m => String -> ScopeT m Name
newName s = ScopeT $ do
  x <- lift newUnique
  return $ Name x s

lookup :: MonadError (Located String) m => Located String -> ScopeT m Name
lookup w = do
  m <- getCurrentScope
  case Map.lookup (extract w) m of
    Just a ->
      return a
    Nothing -> do
      ms <- getScopeChain
      lookup' w ms

lookup' :: MonadError (Located String) m =>
           Located String ->
           [Map String Name] ->
           ScopeT m Name
lookup' w xs =
  case xs of
    y:ys ->
      case Map.lookup s y of
        Just a -> 
          return a
        Nothing ->
          lookup' w ys
    [] -> throwError $ ("scope error: " ++ show s ++ " not defined") <$ w
  where
    s = extract w

nest :: Monad m => ScopeT m a -> ScopeT m a
nest m = ScopeT $ do
  s@S {..} <- get
  put S { currentScope = Map.empty
        , scopeChain = currentScope:scopeChain
        }
  a <- unScopeT m
  put s
  return a
