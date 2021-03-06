{-# LANGUAGE NoMonomorphismRestriction, Rank2Types, RebindableSyntax #-}
{-# OPTIONS_GHC -fno-warn-name-shadowing -fno-warn-unused-do-bind #-}
module Language.Brainfuck.Emitter (emit) where

import Control.Monad (forM_)
import Control.Monad.Fix
import Control.Monad.Code
import Control.Monad.ConstantPool
import Control.Monad.Indexed
import Control.Monad.Indexed.Syntax hiding (return)

import Data.Int

import Language.Brainfuck.Command

import Prelude hiding (Monad (..))

emit :: ( MonadFix (m () ())
        , MonadCode m
        ) => [Command] -> m () () (Label m ())
emit xs = do
  label <- emitHeader
  forM_ xs emitCommand
  emitFooter
  returnM label

emitHeader = do
  label <- ldc 30000
  newarray byte
  astore 1
  ldc 0
  istore 2
  returnM label

emitCommand (IncrementPointer x) = emitIncrementPointer x
emitCommand (IncrementByte x) = emitIncrementByte x
emitCommand OutputByte = emitOutputByte
emitCommand InputByte = emitInputByte
emitCommand (WhileNonzero xs) = emitWhileNonzero xs

emitIncrementPointer = iinc 2

emitIncrementByte x = do
  label <- aload 1
  iload 2
  dup2
  baload
  ldc x
  iadd
  i2b
  bastore
  returnM label

emitOutputByte = do
  label <- getstatic "java/lang/System" "out" (L"java/io/PrintStream")
  aload 1
  iload 2
  baload
  invokevirtual "java/io/PrintStream" "write" (I)V
  returnM label

emitInputByte = do
  label <- aload 1
  iload 2
  getstatic "java/lang/System" "in" (L"java/io/InputStream")
  invokevirtual "java/io/InputStream" "read" ()I
  i2b
  bastore
  returnM label

emitWhileNonzero xs = do
  (start, _) <- mfix (\ ~(_, end) -> do
    start <- aload 1
    iload 2
    baload
    ifeq end
    forM_ xs emitCommand
    goto start
    end <- nop
    returnM (start, end))
  returnM start

emitFooter = do
  label <- nop
  getstatic "java/lang/System" "out" (L"java/io/PrintStream")
  invokevirtual "java/io/PrintStream" "flush" ()V
  return
  returnM label