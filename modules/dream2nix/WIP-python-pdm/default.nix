{
  config,
  lib,
  dream2nix,
  ...
}: let
  libpdm = import ./lib.nix {
    inherit lib libpyproject;
    python3 = config.deps.python;
    targetPlatform =
      lib.systems.elaborate config.deps.python.stdenv.targetPlatform;
  };

  libpyproject = import (dream2nix.inputs.pyproject-nix + "/lib") {inherit lib;};
  libpyproject-fetchers = import (dream2nix.inputs.pyproject-nix + "/fetchers") {
    inherit lib;
    curl = config.deps.curl;
    jq = config.deps.jq;
    python3 = config.deps.python;
    runCommand = config.deps.runCommand;
    stdenvNoCC = config.deps.stdenvNoCC;
  };

  lock_data = lib.importTOML config.pdm.lockfile;
  environ = libpyproject.pep508.mkEnviron config.deps.python;

  pyproject = libpdm.loadPdmPyProject (lib.importTOML config.pdm.pyproject);

  groups_with_deps = libpdm.groupsWithDeps {
    inherit environ pyproject;
  };
  parsed_lock_data = libpdm.parseLockData {
    inherit environ lock_data;
  };
  buildSystemNames =
    map
    (name: (libpyproject.pep508.parseString name).name)
    (pyproject.pyproject.build-system.requires or []);

  commonModule = depConfig: let
    cfg = depConfig.config;
    setuptools =
      if cfg.name == "setuptools"
      then config.deps.python.pkgs.setuptools
      else if config.groups.default.packages ? setuptools
      then (lib.head (lib.attrValues config.groups.default.packages.setuptools)).public
      else config.deps.python.pkgs.setuptools;
  in {
    imports = [
      dream2nix.modules.dream2nix.buildPythonPackage
    ];
    config.mkDerivation.buildInputs =
      lib.optionals
      (! lib.hasSuffix ".whl" cfg.mkDerivation.src)
      [setuptools];
  };
in {
  imports = [
    ../overrides
    ./interface.nix
    ./lock.nix
    commonModule
  ];
  name = pyproject.pyproject.project.name;
  version = lib.mkDefault (
    if pyproject.pyproject.project ? version
    then pyproject.pyproject.project.version
    else if lib.elem "version" pyproject.pyproject.project.dynamic or []
    then "dynamic"
    else "unknown"
  );
  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      autoPatchelfHook
      buildPackages
      curl
      jq
      mkShell
      pdm
      runCommand
      stdenvNoCC
      stdenv
      ;
    python = lib.mkDefault config.deps.python3;
  };
  overrideType = {
    imports = [commonModule];
  };
  overrideAll = {
    deps = {nixpkgs, ...}: {
      python = lib.mkDefault config.deps.python;
    };
  };
  pdm.sourceSelector = lib.mkDefault libpdm.preferWheelSelector;
  buildPythonPackage = {
    format = lib.mkDefault "pyproject";
  };
  mkDerivation = {
    buildInputs = map (name: config.deps.python.pkgs.${name}) buildSystemNames;
    propagatedBuildInputs =
      map
      (x: (lib.head (lib.attrValues x)).public)
      # all packages attrs prefixed with version
      (lib.attrValues config.groups.default.packages);
  };

  public.pyEnv = let
    pyEnv' = config.deps.python.withPackages (ps: config.mkDerivation.propagatedBuildInputs);
  in
    pyEnv'.override (old: {
      # namespaced packages are triggering a collision error, but this can be
      # safely ignored. They are still set up correctly and can be imported.
      ignoreCollisions = true;
    });

  public.devShell = config.deps.mkShell {
    packages = [
      config.public.pyEnv
      config.deps.pdm
    ];
    shellHook = let
      name = libpyproject.pypa.normalizePackageName pyproject.pyproject.project.name;
      pkgInfoFields = {
        Metadata-Version = "2.1";
        Name = name;
        Version = pyproject.pyproject.project.version;
        Summary = pyproject.pyproject.project.description;
      };
      pkgInfo = lib.concatStringsSep "\n" (lib.mapAttrsToList (key: value: "${key}: ${value}") pkgInfoFields);
    in ''
      DREAM_SITE=$PWD/.dream2nix/pdm/site-packages
         	#Prepare .dream2nix/pdm/site-packages
      mkdir -p $DREAM_SITE
      export PYTHONPATH=$DREAM_SITE:$PYTHONPATH
      touch $DREAM_SITE/sitecustomize.py
      echo "import site; site.addsitedir('$DREAM_SITE')" > $DREAM_SITE/sitecustomize.py
      touch $DREAM_SITE/pdm-editable.pth

      #Add PTH locations
      echo "$PWD/src" > $DREAM_SITE/pdm-editable.pth
      echo "$PWD" >> $DREAM_SITE/pdm-editable.pth

      #Add editable packages
      mkdir -p $DREAM_SITE/${name}.egg-info
      touch $DREAM_SITE/${name}.egg-info/PKG-INFO
      echo "${pkgInfo}" > $DREAM_SITE/${name}.egg-info/PKG-INFO
    '';
  };

  groups = let
    groupNames = lib.attrNames groups_with_deps;
    populateGroup = groupname: let
      # Get transitive closure for specific group.
      # The 'default' group is always included no matter the selection.
      transitiveGroupDeps = libpdm.closureForGroups {
        inherit parsed_lock_data groups_with_deps;
        groupNames = lib.unique ["default" groupname];
      };

      packages = lib.flip lib.mapAttrs transitiveGroupDeps (name: pkg: {
        ${pkg.version}.module = {...} @ depConfig: let
          cfg = depConfig.config;
          selector =
            if lib.isFunction cfg.sourceSelector
            then cfg.sourceSelector
            else if cfg.sourceSelector == "wheel"
            then libpdm.preferWheelSelector
            else if cfg.sourceSelector == "sdist"
            then libpdm.preferSdistSelector
            else throw "Invalid sourceSelector: ${cfg.sourceSelector}";
          source = pkg.sources.${selector (lib.attrNames pkg.sources)};
        in {
          imports = [
            ./interface-dependency.nix
            dream2nix.modules.dream2nix.buildPythonPackage
            dream2nix.modules.dream2nix.mkDerivation
            dream2nix.modules.dream2nix.package-func
            (dream2nix.overrides.python.${name} or {})
          ];
          inherit name;
          version = lib.mkDefault pkg.version;
          sourceSelector = lib.mkOptionDefault config.pdm.sourceSelector;
          buildPythonPackage = {
            format = lib.mkDefault (
              if lib.hasSuffix ".whl" source.file
              then "wheel"
              else "pyproject"
            );
          };
          mkDerivation = {
            # TODO: handle sources outside pypi.org
            src = lib.mkDefault (libpyproject-fetchers.fetchFromLegacy {
              pname = name;
              file = source.file;
              hash = source.hash;
              url = "https://pypi.org/simple";
            });
            propagatedBuildInputs =
              lib.mapAttrsToList
              (name: dep: (lib.head (lib.attrValues (config.groups.${groupname}.packages.${name}))).public)
              (libpdm.getClosure parsed_lock_data name pkg.extras);
            nativeBuildInputs =
              lib.optionals config.deps.stdenv.isLinux [config.deps.autoPatchelfHook];
            preFixup = lib.optionalString config.deps.stdenv.isLinux ''
              addAutoPatchelfSearchPath $propagatedBuildInputs
            '';
            doCheck = lib.mkDefault false;
            dontStrip = lib.mkDefault true;
          };
          # required for python.withPackages to recognize it as a python package.
          public.pythonModule = config.deps.python;
        };
      });
    in {inherit packages;};
  in
    lib.genAttrs groupNames populateGroup;
}
