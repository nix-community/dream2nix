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
  dreamLock = utils.readDreamLock { inherit (args) dreamLock; };

  mainPackageName = dreamLock.generic.mainPackage;

  nodejsVersion = dreamLock.buildSystem.nodejsVersion;

  nodejs =
    pkgs."nodejs-${builtins.toString nodejsVersion}_x"
    or (throw "Could not find nodejs version '${nodejsVersion}' in pkgs");

  node2nixEnv = node2nix nodejs;

  node2nixDependencies =
    let
      makeSource = name: 
        let
          packageName = lib.head (lib.splitString "#" name);
        in
          {
            inherit packageName;
            name = lib.strings.sanitizeDerivationName packageName;
            version = dreamLock.sources."${name}".version;
            src = fetchedSources."${name}";
            dependencies =
              lib.forEach
                (lib.filter
                  (depName: ! builtins.elem depName dreamLock.generic.dependencyGraph."${mainPackageName}")
                  (dreamLock.generic.dependencyGraph."${name}" or []))
                (dependency:
                  makeSource dependency
                );
          };
    in
      lib.forEach
        dreamLock.generic.dependencyGraph."${mainPackageName}"
        (dependency: makeSource dependency);

  callNode2Nix = funcName: args:
    node2nixEnv."${funcName}" rec {
      name = lib.strings.sanitizeDerivationName packageName;
      packageName = lib.head (lib.splitString "#" mainPackageName);
      version = dreamLock.sources."${mainPackageName}".version;
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
      src = fetchedSources."${dreamLock.generic.mainPackage}";
    }
    // args;

in
{

  package = callNode2Nix "buildNodePackage" {};

  shell = callNode2Nix "buildNodeShell" {};
    
}
