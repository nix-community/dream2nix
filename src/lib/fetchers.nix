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

  # get information for builtin fetchers
  fetchersDir = ../fetchers;
  fetcherNames = dlib.dirNames fetchersDir;

  # import the builtin fetchers
  fetchersBuiltin =
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

  # import extra fetchers
  importedExtraFetchers =
    l.map
    (module: (callFetcher module) // {inherit (module.extraArgs) name;})
    (dlib.modules.extra.fetchers or []);

  # extend builtin fetchers with extra fetchers
  fetchers =
    l.foldl'
    (acc: el: acc // {${el.name} = el;})
    fetchersBuiltin
    importedExtraFetchers;

  mapFetchers = f:
    l.mapAttrs
    (_: fetcher: f fetcher)
    fetchers;
in {
  inherit fetchers callFetcher mapFetchers;
}
