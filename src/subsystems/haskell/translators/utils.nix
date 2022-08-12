{
  lib,
  pkgs,
  inputs,
}: let
  l = lib // builtins;

  all-cabal-json = inputs.all-cabal-json;

  findJsonFromCabalCandidate = name: version: let
    jsonCabalFile = "${all-cabal-json}/${name}/${version}/${name}.json";
  in
    if (! (l.pathExists jsonCabalFile))
    then throw ''"all-cabal-json" seems to be outdated''
    else l.fromJSON (l.readFile jsonCabalFile);
in {
  inherit findJsonFromCabalCandidate;

  findSha256FromCabalCandidate = name: version: let
    hashFile = "${all-cabal-json}/${name}/${version}/${name}.hashes.json";
  in
    if (! (l.pathExists hashFile))
    then throw ''"all-cabal-json" seems to be outdated''
    else (l.fromJSON (l.readFile hashFile)).package-hashes.SHA256;

  /*
  Convert all cabal files for a given list of candidates to an attrset.
  access like: ${name}.${version}.${some_cabal_attr}
  */
  batchFindJsonFromCabalCandidates = candidates: (l.pipe candidates
    [
      (l.map ({
        name,
        version,
      }: {"${name}" = version;}))
      l.zipAttrs
      (l.mapAttrs (
        name: versions:
          l.genAttrs versions (findJsonFromCabalCandidate name)
      ))
    ]);

  getHackageUrl = {
    name,
    version,
    ...
  }: "https://hackage.haskell.org/package/${name}-${version}.tar.gz";

  getDependencyNames = finalObj: cabalDataAsJson: let
    cabal = with finalObj;
      cabalDataAsJson.${name}.${version};

    targetBuildDepends =
      cabal.library.condTreeData.build-info.targetBuildDepends or [];

    buildToolDepends =
      cabal.library.condTreeData.build-info.buildToolDepends or [];

    defaultFlags = l.filter (flag: flag.default) cabal.package-flags;

    defaultFlagNames = l.map (flag: flag.name) defaultFlags;

    collectBuildDepends = condTreeComponent:
      l.concatMap
      (attrs: attrs.targetBuildDepends)
      (l.collect
        (x: x ? targetBuildDepends)
        condTreeComponent);

    # TODO: use flags to determine which conditional deps are required
    condBuildDepends =
      l.concatMap
      (component: collectBuildDepends component)
      cabal.library.condTreeComponents or [];

    depNames =
      l.map
      (dep: dep.package-name)
      (targetBuildDepends ++ buildToolDepends ++ condBuildDepends);
  in
    depNames;
}
