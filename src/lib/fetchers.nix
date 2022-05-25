{
  dlib,
  lib,
}: let
  l = lib // builtins;

  validator = module: true;
  validateExtraFetcher = module: true;

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
  validatedExtraFetchers =
    l.seq
    (dlib.modules.validateExtraModules validateExtraFetcher importedExtraFetchers)
    importedExtraFetchers;

  fetchersExtended =
    l.foldl'
    (acc: el: acc // {${el.name} = el;})
    fetchers
    validatedExtraFetchers;

  mapFetchers = f:
    l.mapAttrs
    (_: fetcher: f fetcher)
    fetchersExtended;
in {
  fetchers = fetchersExtended;
  inherit callFetcher mapFetchers;
}
