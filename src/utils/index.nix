{
  lib,
  dlib,
  dream2nixInterface,
  ...
}: let
  l = lib // builtins;
  defaultMkPackagesFromDreamLock = dreamLock:
    (dream2nixInterface.makeOutputsForDreamLock {
      inherit dreamLock;
    })
    .packages;
  generatePackagesFromLocks = {
    dreamLocks,
    makePackagesForDreamLock ? defaultMkPackagesFromDreamLock,
  }:
    l.foldl'
    (acc: el: acc // el)
    {}
    (l.map makePackagesForDreamLock dreamLocks);
in {
  generatePackagesFromLocksTree = {
    source ? throw "pass source",
    tree ? dlib.prepareSourceTree {inherit source;},
    makePackagesForDreamLock ? defaultMkPackagesFromDreamLock,
  }: let
    findDreamLocks = tree:
      (
        let
          dreamLockFile = tree.files."dream-lock.json" or {};
        in
          l.optional
          (
            dreamLockFile
            ? content
            && l.stringLength dreamLockFile.content > 0
          )
          dreamLockFile.jsonContent
      )
      ++ (
        l.flatten (
          l.map findDreamLocks
          (l.attrValues tree.directories)
        )
      );
    dreamLocks = findDreamLocks tree;
  in
    generatePackagesFromLocks {
      inherit dreamLocks makePackagesForDreamLock;
    };
}
