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
  buildSystemAttrs,
  dependenciesRemoved,
  mainPackageName,
  mainPackageVersion,
  getDependencies,
  getSource,
  ...
}@args:
let
  b = builtins;

  getDependencies = name: version:
    if dependenciesRemoved ? "${name}" && dependenciesRemoved."${name}" ? "${version}" then
      dependenciesRemoved."${name}"."${version}" ++ (args.getDependencies name version)
    else
      args.getDependencies name version;

  mainPackageKey = "${mainPackageName}#${mainPackageVersion}";

  mainPackageDependencies = getDependencies mainPackageName mainPackageVersion;

  nodejsVersion = buildSystemAttrs.nodejsVersion;

  nodejs =
    pkgs."nodejs-${builtins.toString nodejsVersion}_x"
    or (throw "Could not find nodejs version '${nodejsVersion}' in pkgs");

  node2nixEnv = node2nix nodejs;
  
  node2nixDependencies =
    let
      makeSource = packageName: version:
        {
          inherit packageName version;
          name = utils.sanitizeDerivationName packageName;
          src = getSource packageName version;
          dependencies =
            lib.forEach
              (lib.filter
                (dep: ! builtins.elem dep mainPackageDependencies)
                (getDependencies packageName version))
              (dep:
                makeSource dep.name dep.version
              );
        };
    in
      lib.forEach
        mainPackageDependencies
        (dep: makeSource dep.name dep.version);

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
      src = getSource mainPackageName mainPackageVersion;
    }
    // args;

in
{

  package = callNode2Nix "buildNodePackage" {};

  shell = callNode2Nix "buildNodeShell" {};
    
}
