{
  pkgs,
  lib,
  ...
}: {
  type = "pure";

  build = {
    ### FUNCTIONS
    # AttrSet -> Bool -> AttrSet -> [x]
    getCyclicDependencies, # name: version: -> [ {name=; version=; } ]
    getDependencies, # name: version: -> [ {name=; version=; } ]
    # function that returns a nix-store-path, where a single dependency from the lockfile has been fetched to.
    getSource, # name: version: -> store-path
    # to get information about the original source spec
    getSourceSpec, # name: version: -> {type="git"; url=""; hash="";}
    ### ATTRIBUTES
    subsystemAttrs, # attrset
    defaultPackageName, # string
    defaultPackageVersion, # string
    # all exported (top-level) package names and versions
    # attrset of pname -> version,
    packages,
    # all existing package names and versions
    # attrset of pname -> versions,
    # where versions is a list of version strings
    packageVersions,
    # function which applies overrides to a package
    # It must be applied by the builder to each individual derivation
    # Example:
    # produceDerivation name (mkDerivation {...})
    produceDerivation,
    ...
  }: let
    l = lib // builtins;
    b = builtins;
    inherit (pkgs) stdenv python3 python310Packages makeWrapper jq;

    nodejsVersion = subsystemAttrs.nodejsVersion;

    defaultNodejsVersion = "14";

    isMainPackage = name: version:
      (packages."${name}" or null) == version;

    nodejs =
      if !(l.isString nodejsVersion)
      then pkgs."nodejs-${defaultNodejsVersion}_x"
      else
        pkgs."nodejs-${nodejsVersion}_x"
        or (throw "Could not find nodejs version '${nodejsVersion}' in pkgs");

    # e.g.
    # {
    #   "@babel/core": ["1.0.0","2.0.0"]
    #   ...
    # }
    # is mapped to
    # allPackages = {
    #   "@babel/core": {"1.0.0": pkg-derivation, "2.0.0": pkg-derivation }
    #   ...
    # }
    allPackages =
      lib.mapAttrs
      (
        name: versions:
        # genAttrs takes ["1.0.0, 2.0.0"] returns -> {"1.0.0": makePackage name version}
        # makePackage: produceDerivation: name name (stdenv.mkDerivation {...})
        # returns {"1.0.0": pkg-derivation, "2.0.0": pkg-derivation }
          lib.genAttrs
          versions
          (version: (mkNodeModule name version))
      )
      packageVersions;

    # our builder, written in python. We have huge complexity with how npm builds node_modules
    nodejsBuilder = python310Packages.buildPythonApplication {
      pname = "builder";
      version = "0.1.0";
      src = ./nodejs_builder;
      format = "pyproject";
      nativeBuildInputs = with python310Packages; [poetry mypy flake8 black semantic-version];
      propagatedBuildInputs = with python310Packages; [node-semver];
      doCheck = false;
      meta = {
        description = "Custom builder";
      };
    };

    mkNodeModule = name: version: let
      pname = lib.replaceStrings ["@" "/"] ["__at__" "__slash__"] (name + "@" + version);

      deps = getDependencies name version;

      resolveChildren = {
        name, #a
        version, #1.1.2
        rootVersions,
        # {
        #   "packageNameA": "1.0.0",
        #   "packageNameB": "2.0.0"
        # }
      }: let
        directDeps = getDependencies name version;

        installLocally = name: version: !(rootVersions ? ${name}) || (rootVersions.${name} != version);

        locallyRequiredDeps = b.filter (d: installLocally d.name d.version) directDeps;

        localDepsAttrs = b.listToAttrs (l.map (dep: l.nameValuePair dep.name dep.version) locallyRequiredDeps);
        newRootVersions = rootVersions // localDepsAttrs;

        localDeps =
          l.mapAttrs
          (
            name: version: {
              inherit version;
              dependencies = resolveChildren {
                inherit name version;
                rootVersions = newRootVersions;
              };
            }
          )
          localDepsAttrs;
      in
        localDeps;

      pickVersion = name: versions: directDepsAttrs.${name} or (l.head (l.sort (a: b: l.compareVersions a b == 1) versions));

      packageVersions' = l.mapAttrs (n: v: l.unique v) packageVersions;
      rootPackages = l.mapAttrs (name: versions: pickVersion name versions) packageVersions';

      directDeps = getDependencies name version;
      directDepsAttrs = l.listToAttrs (b.map (dep: l.nameValuePair dep.name dep.version) directDeps);

      nodeModulesTree =
        l.mapAttrs (
          name: version: let
            dependencies = resolveChildren {
              inherit name version;
              rootVersions = rootPackages;
            };
          in {
            inherit version dependencies;
          }
        )
        (l.filterAttrs (n: v: n != name) rootPackages);

      nmTreeJSON = b.toJSON nodeModulesTree;

      depsTree = let
        getDeps = deps: (b.foldl'
          (
            deps: dep:
              deps
              // {
                ${dep.name} =
                  (deps.${dep.name} or {})
                  // {
                    ${dep.version} =
                      (deps.${dep.name}.${dep.version} or {})
                      // {
                        deps = getDeps (getDependencies dep.name dep.version);
                        derivation = allPackages.${dep.name}.${dep.version}.lib;
                      };
                  };
              }
          )
          {}
          deps);
      in (getDeps deps);

      depsTreeJSON = b.toJSON depsTree;

      src = getSource name version;

      pkg = produceDerivation name (
        stdenv.mkDerivation
        {
          inherit nmTreeJSON depsTreeJSON;
          passAsFile = ["nmTreeJSON" "depsTreeJSON"];

          inherit pname version src;

          nativeBuildInputs = [makeWrapper];
          buildInputs = [jq nodejs python3];
          outputs = ["out" "lib" "deps"];

          inherit (pkgs) system;

          packageName = pname;
          name = pname;

          installMethod =
            if isMainPackage name version
            then "copy"
            else "symlink";

          unpackCmd =
            if lib.hasSuffix ".tgz" src
            then "tar --delay-directory-restore -xf $src"
            else null;

          preConfigurePhases = ["d2nPatchPhase" "d2nCheckPhase"];

          unpackPhase = import ./unpackPhase.nix {};

          # nodejs expects HOME to be set
          d2nPatchPhase = ''
            export HOME=$TMPDIR
          '';

          # pre-checks:
          # - platform compatibility (os + arch must match)
          d2nCheckPhase = ''
            # exit code 3 -> the package is incompatible to the current platform
            #  -> Let the build succeed, but don't create node_modules
            ${nodejsBuilder}/bin/d2nCheck  \
            || \
            if [ "$?" == "3" ]; then
              mkdir -p $out
              mkdir -p $lib
              mkdir -p $deps
              echo "Not compatible with system $system" > $lib/error
              exit 0
            else
              exit 1
            fi
          '';

          # create the node_modules folder
          # - uses symlinks as default
          # - symlink the .bin
          # - add PATH to .bin
          configurePhase = ''
            runHook preConfigure

            ${nodejsBuilder}/bin/d2nNodeModules

            export PATH="$PATH:node_modules/.bin"

            runHook postConfigure
          '';

          # only build the main package
          # deps only get unpacked, installed, patched, etc
          dontBuild = ! (isMainPackage name version);
          isMain = isMainPackage name version;
          # Build:
          # npm run build
          # custom build commands for:
          # - electron apps
          # fallback to npm lifecycle hooks, if no build script is present
          buildPhase = ''
            runHook preBuild

            if [ "$(jq '.scripts.build' ./package.json)" != "null" ];
            then
              echo "running npm run build...."
              npm run build
            fi

            runHook postBuild
          '';

          # copy node_modules
          # - symlink .bin
          # - symlink manual pages
          # - dream2nix copies node_modules folder if it is the top-level package
          installPhase = ''
            runHook preInstall

            # remove the symlink (node_modules -> /build/node_modules)
            rm node_modules || true

            if [ -n "$isMain" ];
            then
              echo ----------------------------- copying node_modules into root package---------------------

              # mkdir -p $out/node_modules
              # cp -r /build/node_modules $out
              # cp ./package-lock.json $out/node_modules/.package-lock.json || true

            else
              if [ "$(jq '.scripts.preinstall' ./package.json)" != "null" ]; then
                npm --production --offline --nodedir=$nodeSources run preinstall
              fi
              if [ "$(jq '.scripts.install' ./package.json)" != "null" ]; then
                npm --production --offline --nodedir=$nodeSources run install
              fi
              if [ "$(jq '.scripts.postinstall' ./package.json)" != "null" ]; then
                npm --production --offline --nodedir=$nodeSources run postinstall
              fi
            fi

            ### TODO:
            # $out
            # - $out/lib/pkg-content -> $lib ...(extracted tgz)
            # - $out/lib/node_modules -> $deps
            # - $out/bin

            # $deps
            # - $deps/node_modules

            # $lib
            # - pkg-content (extracted + install scripts runned)


            # copy everything to $out

            cp -r . $lib

            mkdir -p $deps/node_modules


            mkdir -p $out/bin
            mkdir -p $out/lib

            ln -s $lib $out/lib/pkg-content
            ln -s $deps/node_modules $out/lib/node_modules

            runHook postInstall
          '';
        }
      );
    in
      pkg;

    mainPackages =
      b.foldl'
      (ps: p: ps // p)
      {}
      (lib.mapAttrsToList
        (name: version: {
          "${name}"."${version}" = allPackages."${name}"."${version}";
        })
        packages);
  in {
    packages = mainPackages;
  };
}
