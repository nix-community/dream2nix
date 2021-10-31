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
  cyclicDependencies,
  mainPackageName,
  mainPackageVersion,
  getCyclicDependencies,
  getDependencies,
  getSource,
  packageVersions,

  # overrides
  packageOverrides ? {},
  ...
}@args:
let
  b = builtins;

  getDependencies = name: version:
    (args.getDependencies name version) ++ (args.getCyclicDependencies name version);

  mainPackageKey = "${mainPackageName}#${mainPackageVersion}";

  mainPackageDependencies = getDependencies mainPackageName mainPackageVersion;

  nodejsVersion = buildSystemAttrs.nodejsVersion;

  nodejs =
    pkgs."nodejs-${builtins.toString nodejsVersion}_x"
    or (throw "Could not find nodejs version '${nodejsVersion}' in pkgs");

  node2nixEnv = node2nix nodejs;

  # allSources =
  #   lib.mapAttrs
  #     (packageName: versions:
  #       lib.genAttrs versions
  #         (version: {
  #           inherit packageName version;
  #           name = utils.sanitizeDerivationName packageName;
  #           src = getSource packageName version;
  #           dependencies =
  #             # b.trace "current package: ${packageName}#${version}"
  #             lib.forEach
  #               (lib.filter
  #                 (dep: (! builtins.elem dep mainPackageDependencies))
  #                 (getDependencies packageName version))
  #               (dep:
  #                 # b.trace "accessing allSources.${dep.name}.${dep.version}"
  #                 b.trace "${dep.name}#${dep.version}"
  #                 allSources."${dep.name}"."${dep.version}"
  #               );
  #         }))
  #     packageVersions;

  makeSource = packageName: version: prevDeps:
    rec {
      inherit packageName version;
      name = utils.sanitizeDerivationName packageName;
      src = getSource packageName version;
      dependencies =
        let
          parentDeps = prevDeps ++ depsFiltered;
          depsFiltered =
            (lib.filter
            (dep:
              ! b.elem dep prevDeps)
            (getDependencies packageName version));
        in
          lib.forEach
            depsFiltered
            (dep: makeSource dep.name dep.version parentDeps);
    };
  
  node2nixDependencies =
    lib.forEach
      mainPackageDependencies
      (dep: makeSource dep.name dep.version mainPackageDependencies);
      # (dep: allSources."${dep.name}"."${dep.version}");

  callNode2Nix = funcName: args:
    node2nixEnv."${funcName}" (rec {
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
    // args);

in
rec {

  packages."${mainPackageName}"."${mainPackageVersion}" = defaultPackage;

  defaultPackage =
    let
      pkg = callNode2Nix "buildNodePackage" {};
    in
      utils.applyOverridesToPackage packageOverrides pkg mainPackageName;

  devShell = callNode2Nix "buildNodeShell" {};
    
}
