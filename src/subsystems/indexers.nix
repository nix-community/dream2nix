{
  dlib,
  callPackageDream,
  ...
}: let
  makeIndexer = indexerModule:
    indexerModule
    // {
      indexBin = callPackageDream indexerModule.indexBin {};
    };

  indexers = dlib.indexers.mapIndexers makeIndexer;
in {
  inherit
    makeIndexer
    indexers
    ;
}
