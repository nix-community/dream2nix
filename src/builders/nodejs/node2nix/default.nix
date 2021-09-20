# builder imported from node2nix

{
  externals,
  node2nix ? externals.node2nix,

  lib,
  pkgs,
  ...
}:

{
  fetchedSources,
  dreamLock,
}:
let
  mainPackageName = dreamLock.generic.mainPackage;

  nodejsVersion = dreamLock.buildSystem.nodejsVersion;

  nodejs =
    pkgs."nodejs-${builtins.toString nodejsVersion}_x"
    or (throw "Could not find nodejs version '${nodejsVersion}' in pkgs");

  node2nixEnv = node2nix nodejs;

  # make node2nix compatible sources
  makeSource = name: {
    name = lib.head (lib.splitString "#" name);
    packageName = lib.head (lib.splitString "#" name);
    version = dreamLock.sources."${name}".version;
    src = fetchedSources."${name}";
    dependencies = lib.forEach dreamLock.generic.dependencyGraph."${name}" or [] (dependency:
      makeSource dependency
    );
  };

  callNode2Nix = funcName: args:
    node2nixEnv."${funcName}" rec {
      name = mainPackageName;
      packageName = name;
      version = dreamLock.sources."${mainPackageName}".version;
      dependencies =
        lib.forEach
          (lib.filter
            (pname: pname != mainPackageName)
            (lib.attrNames dreamLock.generic.dependencyGraph)
          )
          (dependency: makeSource dependency);
      # buildInputs ? []
      # npmFlags ? ""
      # dontNpmInstall ? false
      # preRebuild ? ""
      # dontStrip ? true
      # unpackPhase ? "true"
      # buildPhase ? "true"
      # meta ? {}
      production = true;
      bypassCache = true;
      reconstructLock = true;
      src = fetchedSources."${dreamLock.generic.mainPackage}";
    }
    // args;

in
{

  package = callNode2Nix "buildNodePackage" {};

  shell = callNode2Nix "buildNodeShell" {};
    
}
