module LibraryModule2Spec where

import Test.Hspec
import LibraryModule2

spec :: Spec
spec = describe "libraryFunction2" $ it "returns the correct string" $
    libraryFunction2 `shouldBe` "Other String"

