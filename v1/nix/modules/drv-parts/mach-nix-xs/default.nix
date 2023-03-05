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

  # Build sdist dependencies.
  # Only build sdists which are not substituted via config.substitutions and which aren't the toplevel
  # package.
  sdists-to-build =
    l.filterAttrs (name: ver: (! substitutions ? ${name}) && name != packageName) sdist-info;
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
    (_: drv: drv.public);

  # The final dists we want to install.
  # A mix of:
  #   - donwloaded wheels
  #   - downloaded sdists built into wheels (see above)
  #   - substitutions from nixpkgs patched for compat with autoPatchelfHook
  finalDistsPaths =
    wheel-dists-paths // (l.mapAttrs getDistDir drv-parts-dists);

  packageName = config.public.name;

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

  # build a wheel for a given sdist
  mkWheelDist = pname: version: distDir: python.pkgs.buildPythonPackage (
    # re-use package attrs from nixpkgs
    # (treat nixpkgs as a source of community overrides)
    (l.optionalAttrs (python.pkgs ? ${pname})
        extractPythonAttrs python.pkgs.${pname})

    # package attributes
    // {
      inherit pname;
      inherit version;
      format = "setuptools";
      # distDir will contain a single file which is the src
      preUnpack = ''export src="${distDir}"/*'';
      # install manualSetupDeps
      pipInstallFlags =
        map (distDir: "--find-links ${distDir}") manualSetupDeps.${pname} or [];
      nativeBuildInputs = [config.deps.autoPatchelfHook];
    }

    # If setup deps have been specified manually, we need to remove the
    #   propagatedBuildInputs from nixpkgs to prevent collisions.
    // lib.optionalAttrs (manualSetupDeps ? ${pname}) {
      propagatedBuildInputs = [];
    }
  );

  makePackage = {name, dependencies}:
    drv-parts.lib.derivationFromModules {
      inherit (config) deps;
    }
      ({config, ...}: let
        file = distFile name;
        version = getVersion file;
        src =
          if isWheel file
          then file
          else mkWheelDist name version (getFetchedDistPath name);
      in {
        imports = [drv-parts.modules.drv-parts.mkDerivation];
        deps = {deps, ...}: {
          inherit (deps) stdenv autoPatchelfHook python pip;
        };

        public = {
          inherit name version;
        };

        mkDerivation = {
          inherit src;

          nativeBuildInputs = [
            config.deps.autoPatchelfHook
          ];

          propagatedBuildInputs = dependencies;

          buildInputs = [
            config.deps.python
            config.deps.python.pkgs.wrapPython
            config.deps.pip
          ];

          unpackPhase = "true";
          installPhase = let
            pythonInterpreter = config.deps.python.pythonForBuild.interpreter;
            pythonSitePackages = config.deps.python.sitePackages;
          in ''
                # TODO there's propably a cleaner way to set PATHs here, this ist just a PoC
                mkdir -p "$out/${pythonSitePackages}" "$out/nix-support"
                buildPythonPath "$propagatedBuildInputs"
                echo $propagatedBuildInputs > $out/nix-support/propagated-build-inputs
                export PYTHONPATH="$program_PYTHONPATH:$out/${pythonSitePackages}:$PYTHONPATH"
                ${pythonInterpreter} -m pip install $src --no-index --no-warn-script-location --prefix="$out" --no-cache $pipInstallFlags
            '';
      });
  # TODO don't depend on config.deps.python for this, because the script should
  # also be able to run for packages using ancient python, without "packaging".
  packagingPython = config.deps.python.withPackages(p: [p.pkginfo p.packaging]);
  dependenciesFile = "${cfg.pythonSources}/dependencies.json";
  dependencies = l.filter (d: d.name != packageName) (l.fromJSON (l.readFile dependenciesFile));

  dependencyTree = l.listToAttrs (
    (l.flip map) dependencies
      (dep: l.nameValuePair dep.name (
        makePackage {
          name = dep.name;
          dependencies = map (pkg: dependencyTree.${pkg}) dep.dependencies;
        })));
in {

  imports = [
    drv-parts.modules.drv-parts.mkDerivation
    (drv-parts.lib.mkDerivation-based "buildPythonPackage")
    ./interface.nix
    ../eval-cache
  ];

  config = {

    mach-nix.lib = {inherit extractPythonAttrs;};

    mach-nix.drvs = l.flip l.mapAttrs all-dists-compat-patchelf (name: dist:
      drv-parts.lib.makeModule {
        packageFunc = dist;
        # TODO: if `overridePythonAttrs` is used here, the .dist output is missing
        #   Maybe a bug in drv-parts?
        overrideFuncName = "overrideAttrs";
        modules = [
          {deps = {inherit (config.deps) stdenv;};}
        ];
      }
    );

    mach-nix.dists =
      l.mapAttrs
      (name: _: getDistInfo name)
      (l.readDir cfg.pythonSources.names);

    deps = {nixpkgs, ...}: l.mapAttrs (_: l.mkDefault) (
      {
        inherit (nixpkgs)
          autoPatchelfHook
          stdenv
          ;
        python = nixpkgs.python3;
        buildPythonPackage = config.deps.python.pkgs.buildPythonPackage;
        manylinuxPackages = nixpkgs.pythonManylinuxPackages.manylinux1;
        fetchPythonRequirements = nixpkgs.callPackage ../../../pkgs/fetchPythonRequirements {};

        runCommand = nixpkgs.runCommand;
        pip = nixpkgs.python3Packages.pip;
      }
    );

    eval-cache.fields = {
      mach-nix.dists = true;
    };

    eval-cache.invalidationFields = {
      mach-nix.pythonSources = true;
    };
    mkDerivation = {
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

      propagatedBuildInputs = l.attrValues dependencyTree;

      passthru = {
        inherit (config.mach-nix) pythonSources;
        dists = finalDistsPaths;
      };
    };
  };
}
