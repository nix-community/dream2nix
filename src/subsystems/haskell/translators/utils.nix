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
    then throw ''Cannot find JSON for version ${version} of package ${name}. "all-cabal-json" may be outdated.''
    else l.fromJSON (l.readFile jsonCabalFile);
in {
  inherit findJsonFromCabalCandidate;

  findSha256FromCabalCandidate = name: version: let
    hashFile = "${all-cabal-json}/${name}/${version}/${name}.hashes.json";
  in
    if (! (l.pathExists hashFile))
    then throw ''Cannot find JSON for version ${version} of package ${name}. "all-cabal-json" may be outdated.''
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

  # XXX: This might be better as a function.  See
  # https://github.com/nixos/nixpkgs/blob/773c2a7afa4cc94f91d53d8cb35245cbf216082b/pkgs/development/haskell-modules/configuration-ghc-9.4.x.nix#L49-L56
  # Packages we shouldn't always overwrite with null, but presently do anyway, are
  # 1) terminfo, when we cross-compile
  # 2) xhtml, when ghc.hasHaddock is set to false
  ghcVersionToHiddenPackages = l.pipe "${inputs.ghc-utils}/library-versions/pkg_versions.txt" [
    l.readFile
    (l.split "\n#+\n# GHC [^\n]+")
    l.tail
    (l.filter l.isString)
    (l.concatMap (l.splitString "\n"))
    (l.filter (s: s != "" && !(l.hasPrefix "HEAD" s)))
    (l.map (
      s: let
        ghcVersionAndHiddenPackages = l.match "([^[:space:]]+)[[:space:]]+(.+)" s;
        ghcVersion = l.head ghcVersionAndHiddenPackages;
        hiddenPackages = l.pipe (l.last ghcVersionAndHiddenPackages) [
          (l.splitString " ")
          (l.map (packageAndVersion:
            l.pipe packageAndVersion [
              (l.match "([^/]+)/.+")
              l.head
              (packageName: l.nameValuePair packageName null)
            ]))
          (pkgNames: [(l.nameValuePair "Win32" null)] ++ pkgNames)
          l.listToAttrs
        ];
      in
        l.nameValuePair ghcVersion hiddenPackages
    ))
    l.listToAttrs
  ];
}
