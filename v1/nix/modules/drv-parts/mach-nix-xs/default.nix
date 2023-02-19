{config, lib, drv-parts, ...}: let

  l = lib // builtins;
  python = config.deps.python;
  cfg = config.mach-nix;

  # For a given name, return the path containing the downloaded file
  getFetchedDistPath = name: cfg.pythonSources.names + "/${name}";

  # For a given name, return the dist output from nixpkgs.buildPythonPackage
  getDistDir = name: dist: dist.dist;

  # separate 2 types of downloaded files: sdist, wheel
  # key: name; val: {version or "wheel"}
  all-info = config.eval-cache.content.mach-nix.dists;
  wheel-info = l.filterAttrs (name: ver: ver == "wheel") all-info;
  sdist-info = l.filterAttrs (name: ver: ! wheel-info ? ${name}) all-info;

  # get the paths of all downlosded wheels
  wheel-dists-paths =
    l.mapAttrs (name: ver: getFetchedDistPath name) wheel-info;

  # Build sdist sources.
  # Only build sdists which are not substituted via config.substitutions.
  sdists-to-build =
    l.filterAttrs (name: ver: ! substitutions ? ${name}) sdist-info;
  new-dists = l.flip l.mapAttrs sdists-to-build
    (name: ver: mkWheelDist name ver (getFetchedDistPath name));
  all-dists = new-dists // substitutions;

  # patch all-dists to ensure build inputs are propagated for autopPatchelflHook
  all-dists-compat-patchelf = l.flip l.mapAttrs all-dists (name: dist:
    dist.overridePythonAttrs (old: {postFixup = "ln -s $out $dist/out";})
  );

  # Convert all-dists to drv-parts drvs.
  # The conversion is done via config.drvs (see below).
  drv-parts-dists = l.flip l.mapAttrs config.mach-nix.drvs
    (_: drv: drv.final.package);

  # The final dists we want to install.
  # A mix of:
  #   - donwloaded wheels
  #   - downloaded sdists built into wheels (see above)
  #   - substitutions from nixpkgs patched for compat with autoPatchelfHook
  finalDistsPaths = wheel-dists-paths // (l.mapAttrs getDistDir drv-parts-dists);

  packageName =
    if config.name != null
    then config.name
    else config.pname;

  unknownSubstitutions = l.attrNames
    (l.removeAttrs cfg.substitutions (l.attrNames all-info));

  # Validate Substitutions. Allow only names that we actually depend on.
  substitutions =
    if unknownSubstitutions == []
    then cfg.substitutions
    else throw ''
      ${"\n"}The following substitutions for python derivation '${packageName}' will not have any effect. There are no dependencies with such names:
        - ${lib.concatStringsSep "\n  - " unknownSubstitutions}
    '';

  manualSetupDeps =
    lib.mapAttrs
    (name: deps: map (dep: finalDistsPaths.${dep}) deps)
    cfg.manualSetupDeps;

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
    distDir = "${cfg.pythonSources.names}/${name}";
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
  in
    package;

in {

  imports = [
    drv-parts.modules.drv-parts.mkDerivation
    ./interface.nix
    ../eval-cache
  ];

  config = {

    mach-nix.lib = {inherit extractPythonAttrs;};

    mach-nix.drvs = l.flip l.mapAttrs all-dists-compat-patchelf (name: dist:
      # A fake module to import other modules
      (_: {
        imports = [
          # generate a module from a package func
          (drv-parts.lib.makeModule (_: dist))
          {deps = {inherit (config.deps) stdenv;};}
        ];
      })
    );

    deps = {nixpkgs, ...}: l.mapAttrs (_: l.mkDefault) (
      {
        inherit (nixpkgs)
          autoPatchelfHook
          fetchPythonRequirements
          stdenv
          ;
        python = nixpkgs.python3;
        manylinuxPackages = nixpkgs.pythonManylinuxPackages.manylinux1;
      }
    );

    eval-cache.fields = {
      mach-nix.dists = true;
    };

    eval-cache.invalidationFields = {
      mach-nix.pythonSources = true;
    };

    mach-nix.dists =
      l.mapAttrs
      (name: _: getDistInfo name)
      (l.readDir cfg.pythonSources.names);

    env = {
      pipInstallFlags =
        ["--ignore-installed"]
        ++ (map (distDir: "--find-links ${distDir}") (l.attrValues finalDistsPaths));
    };

    doCheck = false;
    dontPatchELF = l.mkDefault true;
    dontStrip = l.mkDefault true;

    nativeBuildInputs = [
      config.deps.autoPatchelfHook
    ];

    buildInputs =
      (with config.deps; [
        manylinuxPackages
      ]);

    passthru = {
      inherit (config) pythonSources;
      dists = finalDistsPaths;
    };

    final.package-func = config.deps.python.pkgs.buildPythonPackage;
  };
}
