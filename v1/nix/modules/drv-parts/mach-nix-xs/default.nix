{config, lib, drv-parts, ...}: let

  l = lib // builtins;
  python = config.deps.python;

  manualSetupDeps =
    lib.mapAttrs
    (name: deps: map (dep: wheels.${dep}) deps)
    config.manualSetupDeps;

  # Attributes we never want to copy from nixpkgs
  excludedNixpkgsAttrs = l.genAttrs
    [
      "all"
      "args"
      "builder"
      "name"
      "pname"
      "version"
      "src"
      "outputs"
    ]
    (name: null);

  # Extracts derivation args from a nixpkgs python package.
  nixpkgsAttrsFor = pname: let
    nixpkgsAttrs =
      (python.pkgs.${pname}.overridePythonAttrs (old: {passthru.old = old;}))
      .old;
  in
    if ! python.pkgs ? ${pname}
    then {}
    else l.filterAttrs (name: _: ! excludedNixpkgsAttrs ? ${name}) nixpkgsAttrs;

  # (IFD) Get the dist file for a given name by looking inside (pythonSources)
  distFile = name: let
    distDir = "${config.pythonSources.names}/${name}";
  in
    "${distDir}/${l.head (l.attrNames (builtins.readDir distDir))}";

  isWheel = l.hasSuffix ".whl";

  # Extract the version from a dist's file name
  getVersion = file: let
    base = l.pipe file [
      (l.removeSuffix ".tgx")
      (l.removeSuffix ".tar.gz")
      (l.removeSuffix ".zip")
      (l.removeSuffix ".whl")
    ];
    version = l.last (l.splitString "-" base);
  in
    version;

  # For each dist we need to recall:
  #   - the type (wheel or sdist)
  #   - the version (only needed for sdist, so we can build a wheel)
  getDistInfo = name: let
    file = distFile name;
  in
    if isWheel file
    then "wheel"
    else getVersion file;

  /*
  Ensures that a given dist is a wheel.
  If an sdist dist is given, build a wheel and return its parent directory.
  If a wheel is given, do nothing but return its parent dir.
  */
  ensureWheel = name: version: distDir:
    config.substitutions.${name}.dist or (
      if version == "wheel"
      then distDir
      else mkWheelDist name version distDir
    );

  # derivation attributes for building a wheel
  makePackageAttrs = pname: version: distDir: {
    inherit pname;
    inherit version;
    format = "setuptools";
    pipInstallFlags =
      map (distDir: "--find-links ${distDir}") manualSetupDeps.${pname} or [];

    # distDir will contain a single file which is the src
    preUnpack = ''export src="${distDir}"/*'';
  };

  # build a wheel for a given sdist
  mkWheelDist = pname: version: distDir: let

    package = python.pkgs.buildPythonPackage (

      # re-use package attrs from nixpkgs
      # (treat nixpkgs as a source of community overrides)
      (nixpkgsAttrsFor pname)

      # python attributes
      // (makePackageAttrs pname version distDir)

      # If setup deps have been specified manually, we need to remove the
      #   propagatedBuildInputs from nixpkgs to prevent collisions.
      // lib.optionalAttrs (manualSetupDeps ? ${pname}) {
        propagatedBuildInputs = [];
      }
    );

    finalPackage =
      package.overridePythonAttrs config.overrides.${pname} or (_: {});
  in
    finalPackage.dist;

  # all fetched dists converted to wheels
  wheels =
    l.mapAttrs
    (name: version: ensureWheel name version (config.pythonSources.names + "/${name}"))
    (config.eval-cache.content.mach-nix-dists);

in {

  imports = [
    drv-parts.modules.drv-parts.mkDerivation
    ./interface.nix
    ../eval-cache
  ];

  config = {

    deps = {nixpkgs, ...}: {
      inherit (nixpkgs)
        autoPatchelfHook
        fetchPythonRequirements
        ;
      python = nixpkgs.python38;
      manylinuxPackages = nixpkgs.pythonManylinuxPackages.manylinux1;
    };

    eval-cache.fields = {
      mach-nix-dists = true;
    };

    eval-cache.invalidationFields = {
      pythonSources = true;
    };

    mach-nix-dists =
      l.mapAttrs
      (name: _: getDistInfo name)
      (l.readDir config.pythonSources.names);

    env = {
      pipInstallFlags =
        ["--ignore-installed"]
        ++ (map (distDir: "--find-links ${distDir}") (l.attrValues wheels));
    };

    doCheck = false;
    dontPatchELF = true;

    buildInputs = with config.deps; [
      manylinuxPackages
    ];

    passthru = {
      inherit (config) pythonSources;
      inherit wheels;
    };

    final.derivation =
      config.deps.python.pkgs.buildPythonPackage
      config.final.derivation-args;
  };
}
