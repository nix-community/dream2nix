{config, lib, drv-parts, ...}: let

  l = lib // builtins;

  python = config.deps.python;

  manualSetupDeps =
    lib.mapAttrs
    (name: deps: map (dep: wheels.${dep}) deps)
    config.manualSetupDeps;

  installWheelFiles = directories: ''
    mkdir -p ./dist
    for dep in ${toString directories}; do
      echo "installing dep: $dep"
      cp $dep/* ./dist/
      chmod -R +w ./dist
    done
  '';

  # Attributes we never want to copy from nixpkgs
  excludeNixpkgsAttrs = l.genAttrs
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
    else
      l.filterAttrs
      (name: _: ! excludeNixpkgsAttrs ? ${name})
      nixpkgsAttrs;

  distFile = distDir:
    "${distDir}/${l.head (l.attrNames (builtins.readDir distDir))}";

  isWheel = l.hasSuffix ".whl";

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

  /*
  Ensures that a given file is a wheel.
  If an sdist file is given, build a wheel and put it in $dist.
  If a wheel is given, do nothing but return the path.
  */
  ensureWheel = name: distDir: let
    file = distFile distDir;
  in
    config.substitutions.${name}.dist or (
      if isWheel file
      then distDir
      else mkWheel name file
    );

  mkWheel = pname: distFile: let
    nixpkgsAttrs =
      if isWheel distFile
      then {}
      else nixpkgsAttrsFor pname;
    package = python.pkgs.buildPythonPackage (

      nixpkgsAttrs

      // {
        inherit pname;
        version = getVersion distFile;
        src = distFile;
        format = "setuptools";
        pipInstallFlags = "--find-links ./dist";

        # In case of an sdist src, install all deps so a wheel can be built.
        preInstall = l.optionalString (manualSetupDeps ? ${pname})
          (installWheelFiles manualSetupDeps.${pname});
      }

      # If setup deps have been specified manually, we need to remove the
      #   propagatedBuildInputs from nixpkgs to prevent collisions.
      // lib.optionalAttrs (manualSetupDeps ? ${pname}) {
        propagatedBuildInputs = [];
      }
    );

    finalPackage = package.overridePythonAttrs config.overrides.${pname} or (_: {});
  in
    finalPackage.dist;

  # all fetched sources converted to wheels
  wheels =
    l.mapAttrs
    (name: _: ensureWheel name "${config.pythonSources}/${name}")
    (builtins.readDir config.pythonSources);

in {

  imports = [
    drv-parts.modules.drv-parts.mkDerivation
    ./interface.nix
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

    env = {
      pipInstallFlags = "--ignore-installed";
    };

    doCheck = false;
    dontPatchELF = true;

    preInstall = installWheelFiles (l.attrValues wheels);

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
