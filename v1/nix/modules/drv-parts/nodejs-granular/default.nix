{
  config,
  lib,
  dream2nix,
  ...
}: let
  l = lib // builtins;

  cfg = config.nodejs-granular;

  fetchDreamLockSources =
    import ../../../lib/internal/fetchDreamLockSources.nix
    {inherit lib;};
  getDreamLockSource = import ../../../lib/internal/getDreamLockSource.nix {inherit lib;};
  readDreamLock = import ../../../lib/internal/readDreamLock.nix {inherit lib;};
  hashPath = import ../../../lib/internal/hashPath.nix {
    inherit lib;
    inherit (config.deps) runCommandLocal nix;
  };
  hashFile = import ../../../lib/internal/hashFile.nix {
    inherit lib;
    inherit (config.deps) runCommandLocal nix;
  };

  # fetchers
  fetchers = {
    git = import ../../../lib/internal/fetchers/git {
      inherit hashPath;
      inherit (config.deps) fetchgit;
    };
    http = import ../../../lib/internal/fetchers/http {
      inherit hashFile lib;
      inherit (config.deps.stdenv) mkDerivation;
      inherit (config.deps) fetchurl;
    };
  };

  dreamLockLoaded =
    readDreamLock {inherit (config.nodejs-package-lock) dreamLock;};
  dreamLockInterface = dreamLockLoaded.interface;

  fetchedSources = fetchDreamLockSources {
    inherit (dreamLockInterface) defaultPackageName defaultPackageVersion;
    inherit (dreamLockLoaded.lock) sources;
    inherit fetchers;
  };

  # name: version: -> store-path
  getSource = getDreamLockSource fetchedSources;

  inherit
    (dreamLockInterface)
    getDependencies # name: version: -> [ {name=; version=; } ]
    # Attributes
    
    subsystemAttrs # attrset
    packageVersions
    ;

  isMainPackage = name: version:
    (dreamLockInterface.packages."${name}" or null) == version;

  nodejs = config.deps.nodejs;

  nodeSources = config.deps.runCommandLocal "node-sources" {} ''
    tar --no-same-owner --no-same-permissions -xf ${nodejs.src}
    mv node-* $out
  '';

  nodejsDeps =
    lib.mapAttrs
    (name: versions:
      lib.genAttrs
      versions
      (version:
        makePackage name version))
    packageVersions;

  # Generates a derivation for a specific package name + version
  makePackage = name: version: {config, ...}: {
    imports = [
      (commonModule name)
    ];
    name = lib.replaceStrings ["@" "/"] ["__at__" "__slash__"] name;
    inherit version;
    env = {
      packageName = name;
    };
    mkDerivation = {
      src = getSource name version;
    };
  };

  commonModule = name: {config, ...}: let
    deps = getDependencies name config.version;

    nodeDeps =
      lib.forEach
      deps
      (dep: cfg.nodejsDeps."${dep.name}"."${dep.version}".public);

    passthruDeps =
      l.listToAttrs
      (l.forEach deps
        (dep:
          l.nameValuePair
          dep.name
          cfg.nodejsDeps."${dep.name}"."${dep.version}".public));

    dependenciesJson =
      l.toJSON
      (lib.listToAttrs
        (l.map
          (dep: lib.nameValuePair dep.name dep.version)
          deps));
  in {
    deps = {nixpkgs, ...}:
      l.mapAttrs (_: l.mkDefault) {
        inherit
          (nixpkgs)
          jq
          makeWrapper
          moreutils
          nodejs
          python3
          stdenv
          ;
      };

    mkDerivation = {
      meta =
        subsystemAttrs.meta
        // {
          license =
            l.map (name: l.licenses.${name}) subsystemAttrs.meta.license;
        };

      passthru.dependencies = passthruDeps;

      # prevents running into ulimits
      passAsFile = ["dependenciesJson" "nodeDeps"];

      nativeBuildInputs = [config.deps.makeWrapper];
      buildInputs = with config.deps; [jq nodejs python3];
      preConfigurePhases = ["d2nPatchPhase"];
      dontStrip = true;

      # TODO: upstream fix to nixpkgs
      # example which requires this:
      #   https://registry.npmjs.org/react-window-infinite-loader/-/react-window-infinite-loader-1.0.7.tgz
      unpackCmd =
        if lib.hasSuffix ".tgz" config.mkDerivation.src
        then "tar --delay-directory-restore -xf $src"
        else null;
      unpackPhase = import ./unpackPhase.nix {};

      # - installs dependencies into the node_modules directory
      # - adds executables of direct node module dependencies to PATH
      # - adds the current node module to NODE_PATH
      # - sets HOME=$TMPDIR, as this is required by some npm scripts
      # TODO: don't install dev dependencies. Load into NODE_PATH instead
      configurePhase = import ./configurePhase.nix {
        inherit lib nodeDeps;
      };

      # Runs the install command which defaults to 'npm run postinstall'.
      # Allows using custom install command by overriding 'buildScript'.
      buildPhase = import ./buildPhase.nix {
        inherit (config.deps) jq moreutils;
      };

      # Symlinks executables and manual pages to correct directories
      installPhase = import ./installPhase.nix {
        inherit (config.deps) stdenv;
      };
    };

    env = {
      inherit
        dependenciesJson
        nodeDeps
        nodeSources
        ;

      # The python script wich is executed in this phase:
      #   - ensures that the package is compatible to the current system
      #   - ensures the main version in package.json matches the expected
      #   - pins dependency versions in package.json
      #     (some npm commands might otherwise trigger networking)
      #   - creates symlinks for executables declared in package.json
      # Apart from that:
      #   - Any usage of 'link:' in package.json is replaced with 'file:'
      #   - If package-lock.json exists, it is deleted, as it might conflict
      #     with the parent package-lock.json.

      # costs performance and doesn't seem beneficial in most scenarios
      d2nPatchPhase = ''
        # delete package-lock.json as it can lead to conflicts
        rm -f package-lock.json

        # repair 'link:' -> 'file:'
        mv $nodeModules/$packageName/package.json $nodeModules/$packageName/package.json.old
        cat $nodeModules/$packageName/package.json.old | sed 's!link:!file\:!g' > $nodeModules/$packageName/package.json
        rm $nodeModules/$packageName/package.json.old

        # run python script (see comment above):
        cp package.json package.json.bak
        python $fixPackage \
        || \
        # exit code 3 -> the package is incompatible to the current platform
        #  -> Let the build succeed, but don't create lib/node_modules
        if [ "$?" == "3" ]; then
          mkdir -p $out
          echo "Not compatible with system $system" > $out/error
          exit 0
        else
          exit 1
        fi
      '';

      # python script to modify some metadata to support installation
      # (see comments below on d2nPatchPhase)
      fixPackage = "${./fix-package.py}";

      # script to install (symlink or copy) dependencies.
      installDeps = "${./install-deps.py}";

      # python script to link bin entries from package.json
      linkBins = "${./link-bins.py}";
    };

    nodejs-granular = {
      /*
      For top-level packages install dependencies as full copies, as this
      reduces errors with build tooling that doesn't cope well with
      symlinking.
      */
      installMethod =
        if isMainPackage name config.version
        then "copy"
        else "symlink";

      # only run build on the main package
      runBuild = isMainPackage name config.version;

      # can be overridden to define alternative install command
      # (defaults to 'npm run postinstall')
      buildScript = null;
    };
  };
in {
  imports = [
    ./interface.nix
    dream2nix.modules.drv-parts.mkDerivation
    (commonModule config.name)
  ];
  deps = {nixpkgs, ...}: {
    inherit (nixpkgs) mkShell;
  };
  env = {
    packageName = config.name;
  };
  mkDerivation = {
    passthru.devShell = import ./devShell.nix {
      inherit (config.deps) nodejs mkShell;
      inherit (config.env) packageName;
      pkg = config.public;
    };
  };
  nodejs-granular = {
    inherit nodejsDeps;
  };
}
