{-# LANGUAGE CPP #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
module Text.Shakespeare.TextSpec (spec) where

import HamletTestTypes (ARecord(..))

import Test.HUnit hiding (Test)
import Test.Hspec

import Prelude hiding (reverse)
import Text.Shakespeare.Text
import Data.List (intercalate)
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import Data.Text.Lazy.Builder (toLazyText)
import qualified Data.List
import qualified Data.List as L
import Data.Text (Text, pack, unpack)
import Data.Monoid (mappend)

import Text.Shakespeare.BuilderQQ

spec :: Spec
spec = do
    it "text" $ do
      let var = "var"
      let urlp = (Home, [(pack "p", pack "q")])
      flip telper [text|שלום
#{var}
@{Home}
@?{urlp}
^{jmixin}
|] $ intercalate "\n"
        [ "שלום"
        , var
        , "url"
        , "url?p=q"
        , "var x;"
        ] ++ "\n"


    it "textFile" $ do
      let var = "var"
      let urlp = (Home, [(pack "p", pack "q")])
      flip telper $(textFile "test/texts/external1.text") $ unlines
          [ "שלום"
          , var
          , "url"
          , "url?p=q"
          , "var x;"
          ]


    it "textFileReload" $ do
      let var = "var"
      let urlp = (Home, [(pack "p", pack "q")])
      flip telper $(textFileReload "test/texts/external1.text") $ unlines
          [ "שלום"
          , var
          , "url"
          , "url?p=q"
          , "var x;"
          ]

{- TODO
    it "textFileReload" $ do
      let var = "somevar"
          test result = telper result $(textFileReload "test/texts/external2.text")
      writeFile "test/texts/external2.text" "var #{var} = 1;"
      test "var somevar = 1;"
      writeFile "test/texts/external2.text" "var #{var} = 2;"
      test "var somevar = 2;"
      writeFile "test/texts/external2.text" "var #{var} = 1;"
      -}

    it "stextFile" $ do
      let var = "somevar"
      TL.toStrict $(stextFile "test/texts/external2.text") @=? pack "var somevar = 2;"

    it "text module names" $
      let foo = "foo"
          double = 3.14 :: Double
          int = -5 :: Int in
        telper "oof oof 3.14 -5"
          [text|#{Data.List.reverse foo} #{L.reverse foo} #{show double} #{show int}|]

    it "stext module names" $
      let foo = "foo"
          double = 3.14 :: Double
          int = -5 :: Int in
        simpT "oof oof 3.14 -5"
          [stext|#{Data.List.reverse foo} #{L.reverse foo} #{show double} #{show int}|]

    it "single dollar at and caret" $ do
      telper "$@^" [text|$@^|]
      telper "#{@{^{" [text|#\{@\{^\{|]

    it "single dollar at and caret" $ do
      simpT "$@^" [stext|$@^|]
      simpT "#{@{^{" [stext|#\{@\{^\{|]

    it "dollar operator" $ do
      let val = (1 :: Int, (2 :: Int, 3 :: Int))
      telper "2" [text|#{ show $ fst $ snd val }|]
      telper "2" [text|#{ show $ fst $ snd $ val}|]

    it "dollar operator" $ do
      let val = (1 :: Int, (2 :: Int, 3 :: Int))
      simpT "2" [stext|#{ show $ fst $ snd val }|]
      simpT "2" [stext|#{ show $ fst $ snd $ val}|]

    it "aligned text with bar" $ do
      let val = 3 :: Int
      simpT "hoge\r\n3\r\n1\r\n" (TL.fromStrict [sbt|hoge
                                                    |#{val}
                                                    |1
                                                    |])
      simpT "hoge\r\n3\r\n1\r\n" [lbt|hoge
                                     |#{val}
                                     |1
                                     |]

    it "caret operation with justVarInterpolation = True" $ do
      let val = 2 :: Int
      let bld = [builderQQ|#{ show val }|]
      simpT "2" $ toLazyText [builderQQ|^{ bld }|]
    
#if MIN_VERSION_template_haskell(2,18,0)
    it "record dot" $ do
      let z = ARecord 22 True
      telper "221" [text|#{z.field1}#{fromEnum z.field2}|]
#endif

simpT :: String -> TL.Text -> Assertion
simpT a b = nocrlf (pack a) @=? nocrlf (TL.toStrict b)
  where
    nocrlf = T.replace (pack "\r\n") (pack "\n")


data Url = Home | Sub SubUrl
data SubUrl = SubUrl
render :: Url -> [(Text, Text)] -> Text
render Home qs = pack "url" `mappend` showParams qs
render (Sub SubUrl) qs = pack "suburl" `mappend` showParams qs

showParams :: [(Text, Text)] -> Text
showParams [] = pack ""
showParams z =
    pack $ '?' : intercalate "&" (map go z)
  where
    go (x, y) = go' x ++ '=' : go' y
    go' = concatMap encodeUrlChar . unpack

-- | Taken straight from web-encodings; reimplemented here to avoid extra
-- dependencies.
encodeUrlChar :: Char -> String
encodeUrlChar c
    -- List of unreserved characters per RFC 3986
    -- Gleaned from http://en.wikipedia.org/wiki/Percent-encoding
    | 'A' <= c && c <= 'Z' = [c]
    | 'a' <= c && c <= 'z' = [c]
    | '0' <= c && c <= '9' = [c]
encodeUrlChar c@'-' = [c]
encodeUrlChar c@'_' = [c]
encodeUrlChar c@'.' = [c]
encodeUrlChar c@'~' = [c]
encodeUrlChar ' ' = "+"
encodeUrlChar y =
    let (a, c) = fromEnum y `divMod` 16
        b = a `mod` 16
        showHex' x
            | x < 10 = toEnum $ x + (fromEnum '0')
            | x < 16 = toEnum $ x - 10 + (fromEnum 'A')
            | otherwise = error $ "Invalid argument to showHex: " ++ show x
     in ['%', showHex' b, showHex' c]




jmixin :: TextUrl url
jmixin = [text|var x;|]

telper :: String -> TextUrl Url -> Assertion
telper res h = pack res @=? TL.toStrict (renderTextUrl render h)

instance Show Url where
    show _ = "FIXME remove this instance show Url"
