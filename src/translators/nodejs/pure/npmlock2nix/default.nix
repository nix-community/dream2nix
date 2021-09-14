{
  externals,
  translatorName,
}:

let
  translate =
    {
      inputFiles,
      ...
    }:
    let
      parsed = externals.npmlock2nix.readLockfile (builtins.elemAt inputFiles 0);
    in
    {
      sources = builtins.mapAttrs (pname: pdata:{
        url = pdata.resolved;
        type = "fetchurl";
        hash = pdata.integrity;
      }) parsed.dependencies;

      generic = {
        buildSystem = "nodejs";
        buildSystemFormatVersion = 1;
        producedBy = translatorName;
        dependencyGraph = null;
        sourcesCombinedHash = null;
      };

      buildSystem = {
        nodejsVersion = 14;
      };
    };

in

{
  inherit translate;
}
