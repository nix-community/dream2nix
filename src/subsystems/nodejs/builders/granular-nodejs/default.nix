{
  pkgs,
  lib,
  ...
}: {
  type = "pure";

  build = let
    inherit
      (pkgs)
      jq
      makeWrapper
      mkShell
      python3
      runCommandLocal
      stdenv
      python310Packages
      ;
  in
    {
      # Funcs
      # AttrSet -> Bool) -> AttrSet -> [x]
      getCyclicDependencies, # name: version: -> [ {name=; version=; } ]
      getDependencies, # name: version: -> [ {name=; version=; } ]
      getSource, # name: version: -> store-path
      # Attributes
      subsystemAttrs, # attrset
      defaultPackageName, # string
      defaultPackageVersion, # string
      packages, # list
      # attrset of pname -> versions,
      # where versions is a list of version strings
      packageVersions,
      # function which applies overrides to a package
      # It must be applied by the builder to each individual derivation
      # Example:
      #   produceDerivation name (mkDerivation {...})
      produceDerivation,
      nodejs ? null,
      ...
    } @ args: let
      b = builtins;
      l = lib // builtins;

      nodejsVersion = subsystemAttrs.nodejsVersion;

      isMainPackage = name: version:
        (args.packages."${name}" or null) == version;

      nodejs =
        if args ? nodejs
        then b.toString args.nodejs
        else
          pkgs."nodejs-${nodejsVersion}_x"
          or (throw "Could not find nodejs version '${nodejsVersion}' in pkgs");

      nodeSources = runCommandLocal "node-sources" {} ''
        tar --no-same-owner --no-same-permissions -xf ${nodejs.src}
        mv node-* $out
      '';

      binTestApp = python310Packages.buildPythonApplication {
        pname = "builder";
        version = "0.1.0";
        src = ./bin_tests;
        format = "pyproject";
        nativeBuildInputs = with python310Packages; [poetry mypy flake8 black];
        doCheck = false;
        meta = {
          description = "Custom binary tests";
        };
      };

      allPackages =
        lib.mapAttrs
        (name: versions:
          lib.genAttrs
          versions
          (version:
            makePackage name version))
        packageVersions;

      outputs = rec {
        # select only the packages listed in dreamLock as main packages
        packages =
          b.foldl'
          (ps: p: ps // p)
          {}
          (lib.mapAttrsToList
            (name: version: {
              "${name}"."${version}" = allPackages."${name}"."${version}";
            })
            args.packages);

        devShells =
          {default = devShells.${defaultPackageName};}
          // (
            l.mapAttrs
            (name: version: allPackages.${name}.${version}.devShell)
            args.packages
          );
      };

      # Generates a derivation for a specific package name + version
      makePackage = name: version: let
        pname = lib.replaceStrings ["@" "/"] ["__at__" "__slash__"] name;

        deps = getDependencies name version;

        nodeDeps =
          lib.forEach
          deps
          (dep: allPackages."${dep.name}"."${dep.version}");

        passthruDeps =
          l.listToAttrs
          (l.forEach deps
            (dep:
              l.nameValuePair
              dep.name
              allPackages."${dep.name}"."${dep.version}"));

        dependenciesJson =
          b.toJSON
          (lib.listToAttrs
            (b.map
              (dep: lib.nameValuePair dep.name dep.version)
              deps));

        electronDep =
          if ! isMainPackage name version
          then null
          else
            lib.findFirst
            (dep: dep.name == "electron")
            null
            deps;

        electronVersionMajor =
          lib.versions.major electronDep.version;

        electronHeaders =
          if
            (electronDep == null)
            # hashes seem unavailable for electron < 4
            || ((l.toInt electronVersionMajor) <= 2)
          then null
          else pkgs."electron_${electronVersionMajor}".headers;

        pkg = produceDerivation name (stdenv.mkDerivation rec {
          inherit
            dependenciesJson
            electronHeaders
            nodeDeps
            nodeSources
            version
            ;

          packageName = name;

          inherit pname;

          meta = let
            meta = subsystemAttrs.meta;
          in
            meta
            // {
              license = l.map (name: l.licenses.${name}) meta.license;
            };

          passthru.dependencies = passthruDeps;

          passthru.devShell = import ./devShell.nix {
            inherit
              mkShell
              nodejs
              packageName
              pkg
              ;
          };

          /*
          For top-level packages install dependencies as full copies, as this
          reduces errors with build tooling that doesn't cope well with
          symlinking.
          */
          installMethod =
            if isMainPackage name version
            then "copy"
            else "symlink";

          electronAppDir = ".";

          # only run build on the main package
          runBuild = isMainPackage name version;

          src = getSource name version;

          nativeBuildInputs = [makeWrapper];

          buildInputs = [jq nodejs python3];

          preConfigurePhases = ["d2nPatchPhase"];

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
          # prevents running into ulimits
          passAsFile = ["dependenciesJson" "nodeDeps"];

          # can be overridden to define alternative install command
          # (defaults to 'npm run postinstall')
          buildScript = null;

          # python script to modify some metadata to support installation
          # (see comments below on d2nPatchPhase)
          fixPackage = "${./fix-package.py}";

          # script to install (symlink or copy) dependencies.
          installDeps = "${./install-deps.py}";

          # python script to link bin entries from package.json
          linkBins = "${./link-bins.py}";

          # costs performance and doesn't seem beneficial in most scenarios
          dontStrip = true;

          # TODO: upstream fix to nixpkgs
          # example which requires this:
          #   https://registry.npmjs.org/react-window-infinite-loader/-/react-window-infinite-loader-1.0.7.tgz
          unpackCmd =
            if lib.hasSuffix ".tgz" src
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
            inherit pkgs;
          };

          # Symlinks executables and manual pages to correct directories
          installPhase = import ./installPhase.nix {
            inherit pkgs;
          };

          # check all binaries of the top level package
          # doInstallCheck = isMainPackage packageName version;
          doInstallCheck = true;
          # list of binaries that cannot be tested
          # because the dont accept any args from [--help --version -h -v] but do actually run
          installCheckExcludes = ["tsserver" "is-ci" "browserslist-lint" "multicast-dns" "tree-kill" "errno" "opener" "json5" "is-docker" "eslint-config-prettier-check" "node-gyp-build" "node-gyp-build-test" "node-which"];
          installCheckPhase = ''
            ${binTestApp}/bin/d2nCheck
          '';
        });
      in
        pkg;
    in
      outputs;
}
