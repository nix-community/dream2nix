{
  dlib,
  lib,
}: let
  l = lib // builtins;

  # TODO:
  validator = module: true;

  callFetcher = {
    file,
    extraArgs ? {},
  }:
    dlib.modules.importModule {inherit file extraArgs validator;};

  fetchersDir = ../fetchers;
  fetcherNames = dlib.dirNames fetchersDir;
  fetchers =
    l.genAttrs
    fetcherNames
    (
      name: let
        extraArgs = {inherit name;};
      in
        (callFetcher {
          file = "${fetchersDir}/${name}";
          inherit extraArgs;
        })
        // extraArgs
    );

  importedExtraFetchers =
    l.map
    (module: (callFetcher module) // {inherit (module.extraArgs) name;})
    (dlib.modules.extra.fetchers or []);

  fetchersExtended =
    l.foldl'
    (acc: el: acc // {${el.name} = el;})
    fetchers
    importedExtraFetchers;

  mapFetchers = f:
    l.mapAttrs
    (_: fetcher: f fetcher)
    fetchersExtended;
in {
  fetchers = fetchersExtended;
  inherit callFetcher mapFetchers;
}
