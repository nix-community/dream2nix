{
  lib,
  pkgs,
  all-cabal-json,
}: let
  l = lib // builtins;

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
}
