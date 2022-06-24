{
  dlib,
  lib,
}: let
  l = lib // builtins;

  # TODO:
  validator = module: true;

  callIndexer = file: extraArgs:
    dlib.modules.importModule {inherit file extraArgs validator;};

  # get information for builtin indexers
  indexersDir = ../indexers;
  indexerNames = dlib.dirNames indexersDir;

  # get the builtin indexers
  builtinIndexers =
    l.map
    (name: {
      file = "${indexersDir}/${name}";
      extraArgs = {inherit name;};
    })
    indexerNames;
  # get extra indexers
  extraIndexers = dlib.modules.extra.indexers or [];

  # import indexers
  importedIndexers =
    l.map
    (
      module:
        (callIndexer module.file module.extraArgs)
        // {inherit (module.extraArgs) name;}
    )
    (builtinIndexers ++ extraIndexers);
  # create the attrset
  indexers = l.listToAttrs (l.map (f: l.nameValuePair f.name f) importedIndexers);
  mapIndexers = f: l.mapAttrs (_: indexer: f indexer) indexers;
in {inherit indexers callIndexer mapIndexers;}
