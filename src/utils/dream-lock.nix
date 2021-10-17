{
  lib,
  ...
}:
let

  b = builtins;

  readDreamLock = 
    {
      dreamLock,
    }@args:
    let
      lock =
        if b.isPath dreamLock then
          b.fromJSON (b.readFile dreamLock)
        else
          dreamLock;
      mainPackage = lock.generic.mainPackage;
      dependencyGraph = lock.generic.dependencyGraph;
    in
      lock;

in
  {
    inherit readDreamLock;
  }

