module LibraryModuleSpec where

import Test.Hspec
import LibraryModule

spec :: Spec
spec = describe "libraryFunction" $ it "returns the correct string" $
    libraryFunction `shouldBe` "Some String"

