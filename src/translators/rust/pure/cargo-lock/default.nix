{
  externals,
  translatorName,
  utils,
  lib,
  runCommandNoCC,
  ...
}:

let
  translate =
    {
      inputPaths,
      ...
    }:
    let
      cargoLock = builtins.fromTOML (builtins.readFile (builtins.elemAt inputPaths 0));
      parsed = builtins.listToAttrs (map (p: lib.nameValuePair p.name p) cargoLock.package);
    in
    {
      sources = builtins.mapAttrs (pname: pdata:
        if pdata ? source && pdata ? checksum then
          {
            url = "https://crates.io/api/v1/crates/${pdata.name}/${pdata.version}/download"; 
            type = "fetchurl";
            hash = pdata.checksum;
          }
        else
          {
            path = ./.;
            type = "path";
          }
      ) parsed;

      generic = {
        buildSystem = "rust";
        buildSystemFormatVersion = 1;
        producedBy = translatorName;
        dependencyGraph = null;
        sourcesCombinedHash = null;
      };
    };

    compatiblePaths = paths: utils.compatibleTopLevelPaths ".*(Cargo\\.lock)" paths;

in

{
  inherit translate compatiblePaths;
}
