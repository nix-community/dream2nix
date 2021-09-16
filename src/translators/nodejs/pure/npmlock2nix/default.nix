{
  lib,

  externals,
  translatorName,
  utils,
  ...
}:

{
  translate =
    {
      inputDirectories,
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

  compatiblePaths =
    {
      inputDirectories,
      inputFiles,
    }@args:
    builtins.trace (lib.attrValues args)
    {
      inputDirectories = [];
      inputFiles =
        lib.filter (f: builtins.match ".*(package-lock\\.json)" f != null) args.inputFiles;
    };
}
