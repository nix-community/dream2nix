# builder imported from node2nix

{
  lib,
  pkgs,

  # dream2nix inputs
  externals,
  node2nix ? externals.node2nix,
  utils,
  ...
}:

{
  fetchedSources,
  dreamLock,
  ...
}@args:
let
  b = builtins;

  dreamLock = utils.readDreamLock { inherit (args) dreamLock; };

  mainPackageName = dreamLock.generic.mainPackageName;
  mainPackageVersion = dreamLock.generic.mainPackageVersion;
  mainPackageKey = "${mainPackageName}#${mainPackageVersion}";

  nodejsVersion = dreamLock.buildSystem.nodejsVersion;

  nodejs =
    pkgs."nodejs-${builtins.toString nodejsVersion}_x"
    or (throw "Could not find nodejs version '${nodejsVersion}' in pkgs");

  node2nixEnv = node2nix nodejs;

  node2nixDependencies =
    let
      makeSource = name: 
        let
          nameVer = lib.splitString "#" name;
          packageName = lib.elemAt nameVer 0;
          version = lib.elemAt nameVer 1;
        in
          {
            inherit packageName version;
            name = utils.sanitizeDerivationName packageName;
            src = fetchedSources."${name}";
            dependencies =
              lib.forEach
                (lib.filter
                  (depName: ! builtins.elem depName dreamLock.generic.dependencyGraph."${mainPackageKey}")
                  (dreamLock.generic.dependencyGraph."${name}" or []))
                (dependency:
                  makeSource dependency
                );
          };
    in
      lib.forEach
        dreamLock.generic.dependencyGraph."${mainPackageKey}"
        (dependency: makeSource dependency);

  callNode2Nix = funcName: args:
    node2nixEnv."${funcName}" rec {
      name = utils.sanitizeDerivationName packageName;
      packageName = mainPackageName;
      version = mainPackageVersion;
      dependencies = node2nixDependencies;
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
      src = fetchedSources."${mainPackageKey}";
    }
    // args;

in
{

  package = callNode2Nix "buildNodePackage" {};

  shell = callNode2Nix "buildNodeShell" {};
    
}
