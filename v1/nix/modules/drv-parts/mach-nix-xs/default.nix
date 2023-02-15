{config, lib, drv-parts, ...}: let

  l = lib // builtins;
  python = config.deps.python;

  packageName =
    if config.name != null
    then config.name
    else config.pname;

  unknownSubstitutions = l.attrNames
    (l.removeAttrs config.substitutions (l.attrNames wheels));

  # Validate Substitutions. Allow only names that we actually depend on.
  substitutions =
    if unknownSubstitutions == []
    then config.substitutions
    else throw ''
      ${"\n"}The following substitutions for python derivation '${packageName}' will not have any effect. There are no dependencies with such names:
        - ${lib.concatStringsSep "\n  - " unknownSubstitutions}
    '';

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
  extractPythonAttrs = pythonPackage: let
    extractOverrideAttrs = overrideFunc:
      (pythonPackage.${overrideFunc} (old: {passthru.old = old;}))
      .old;
    pythonAttrs = extractOverrideAttrs "overridePythonAttrs";
    allAttrs = pythonAttrs;
  in
    l.filterAttrs (name: _: ! excludedNixpkgsAttrs ? ${name}) allAttrs;

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
    substitutions.${name}.dist or (
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
      (l.optionalAttrs (python.pkgs ? ${pname})
          extractPythonAttrs python.pkgs.${pname})

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

    mach-nix.lib = {inherit extractPythonAttrs;};

    deps = {nixpkgs, ...}: {
      inherit (nixpkgs)
        autoPatchelfHook
        fetchPythonRequirements
        ;
      python = nixpkgs.python3;
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
    dontPatchELF = l.mkDefault true;
    dontStrip = l.mkDefault true;

    nativeBuildInputs = [
      config.deps.autoPatchelfHook
    ];

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
