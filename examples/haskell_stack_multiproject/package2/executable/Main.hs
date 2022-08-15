module Main where

import LibraryModule
import LibraryModule2

main :: IO ()
main = putStrLn $ libraryFunction ++ libraryFunction2
