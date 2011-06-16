{
{-# LANGUAGE DeriveFunctor, StandaloneDeriving #-}
{-# OPTIONS_GHC
    -fno-warn-lazy-unlifted-bindings
    -fno-warn-missing-signatures
    -fno-warn-name-shadowing
    -fno-warn-unused-binds
    -fno-warn-unused-matches#-}
module Language.TNT.Lexer where

import Codec.Binary.UTF8.String (decode)

import Control.Applicative

import Data.ByteString.Lazy (ByteString)
import qualified Data.ByteString.Lazy as BL
import Data.Word

import Language.TNT.Token
}

%wrapper "monadUserState-bytestring"

$digit = 0-9
$alpha = [a-zA-Z]

@name = $alpha [$alpha $digit \_]*

:-
  <0> \n { newline }
  <0> $white ;
  <0> "//".* ;
  <0> "import" { import' }
  <0> @name { name }
  <0> \" { beginString `andBegin` string }
  <string> "\\" { begin escapedChar }
  <escapedChar> \" { char `andBegin` string }
  <string> \" { endString `andBegin` 0}
  <string> . { char }
  <0> "=" { equals }
  <0> "." { dot }
  <0> "," { comma }
  <0> "(" { openParen }
  <0> ")" { closeParen }
  <0> ";" { semi }

{

deriving instance Functor Alex
  
type AlexUserState = [Word8] -> [Word8]

name :: AlexAction (Alex Token)
name (p, _, s) x = return a 
  where
    a = Token (Name . toString $ BL.take (fromIntegral x) s) (fromAlexPosn p)

beginString :: AlexAction (Alex Token)
beginString _ _ = alexSetUserState id >> alexMonadScan

char :: AlexAction (Alex Token)
char (_, _, s) x = alexGetUserState >>=
                   alexSetUserState . f >>
                   alexMonadScan
  where
    f = (. (BL.unpack (BL.take (fromIntegral x) s) ++))

endString :: AlexAction (Alex Token)
endString (p, _, _) _ = f <$> alexGetUserState
  where
    f = flip Token (fromAlexPosn p) . String . decode . ($ [])

import' = token' Import
equals = token' Equals
dot = token' Dot
comma = token' Comma
openParen = token' OpenParen
closeParen = token' CloseParen
semi = token' Semi
newline = token' Newline

token' x (p, _, _) _ = return $ Token x $ fromAlexPosn p

alexEOF :: Alex Token
alexEOF = return EOF

alexInitUserState :: AlexUserState
alexInitUserState = id

alexGetUserState :: Alex AlexUserState
alexGetUserState = Alex $ \s@AlexState { alex_ust = ust} -> Right (s, ust)

alexSetUserState :: AlexUserState -> Alex ()
alexSetUserState ust = Alex $ \s -> Right (s { alex_ust = ust }, ())

fromAlexPosn :: AlexPosn -> Position
fromAlexPosn (AlexPn _ x y) = x :+: y

toString :: ByteString -> String
toString = decode . BL.unpack
}