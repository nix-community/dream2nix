{
  dlib,
  lib,
}: let
  l = lib // builtins;

  # TODO:
  validator = module: true;

  callFetcher = file: extraArgs:
    dlib.modules.importModule {inherit file extraArgs validator;};

  # get information for builtin fetchers
  fetchersDir = ../fetchers;
  fetcherNames = dlib.dirNames fetchersDir;

  # get the builtin fetchers
  builtinFetchers =
    l.map
    (name: {
      file = "${fetchersDir}/${name}";
      extraArgs = {inherit name;};
    })
    fetcherNames;
  # get extra fetchers
  extraFetchers = dlib.modules.extra.fetchers or [];

  # import fetchers
  importedFetchers =
    l.map
    (
      module:
        (callFetcher module.file module.extraArgs)
        // {inherit (module.extraArgs) name;}
    )
    (builtinFetchers ++ extraFetchers);
  # create the attrset
  fetchers = l.listToAttrs (l.map (f: l.nameValuePair f.name f) importedFetchers);

  mapFetchers = f: l.mapAttrs (_: fetcher: f fetcher) fetchers;
in {
  inherit fetchers callFetcher mapFetchers;
}
