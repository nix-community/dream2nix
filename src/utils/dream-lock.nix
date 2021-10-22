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
        if b.isPath dreamLock || b.isString dreamLock then
          b.fromJSON (b.readFile dreamLock)
        else
          dreamLock;
      mainPackage = lock.generic.mainPackage;
      dependencyGraph = lock.generic.dependencyGraph;
    in
      lock;

  getMainPackageSource = dreamLock:
    dreamLock.sources
      ."${dreamLock.generic.mainPackageName}"
      ."${dreamLock.generic.mainPackageVersion}";


in
  {
    inherit getMainPackageSource readDreamLock;
  }
