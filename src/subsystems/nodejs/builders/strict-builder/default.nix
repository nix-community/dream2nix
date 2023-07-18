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
    # function that returns a nix-store-path, where a single dependency
    # from the lockfile has been fetched to.
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
    # type:
    #   packageVersions :: {
    #    ${pname} :: [ ${version} ]
    # }
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

    inherit (import ./python-builder {inherit pkgs;}) nodejsBuilder;

    nodejsVersion = subsystemAttrs.nodejsVersion;

    defaultNodejsVersion = l.versions.major pkgs.nodejs.version;

    isMainPackage = name: version:
      (packages."${name}" or null) == version;

    nodejs =
      if !(l.isString nodejsVersion)
      then pkgs."nodejs-${defaultNodejsVersion}_x"
      else
        pkgs."nodejs-${nodejsVersion}_x"
        or (throw "Could not find nodejs version '${nodejsVersion}' in pkgs");

    nodeSources = pkgs.runCommandLocal "node-sources" {} ''
      tar --no-same-owner --no-same-permissions -xf ${nodejs.src}
      mv node-* $out
    '';

    # Every package is mapped to a derivation
    # type:
    #   allPackages :: {
    #     ${pname} :: {
    #       ${version} :: Derivation
    #     }
    #   }
    allPackages =
      lib.mapAttrs
      (
        name: versions:
          lib.genAttrs
          versions
          (version: (mkPackage {inherit name version;}))
      )
      packageVersions;

    # function that 'builds' a package's derivation.
    # type:
    #   mkPackage :: {
    #     name :: String,
    #     version :: String,
    #   } -> Derivation
    mkPackage = {
      name,
      version,
    }: let
      src = getSource name version;
      pname = lib.replaceStrings ["@" "/"] ["__at__" "__slash__"] name;

      # all direct dependencies of current package
      # Type: deps :: [ { name :: String, version :: String } ]
      directDeps = getDependencies name version;

      inherit
        (import ./lib/node-modules-tree.nix {
          inherit pkgs lib getDependencies packageVersions name version;
          nodeModulesBuilder = "${nodejsBuilder}/bin/d2nNodeModules";
        })
        mkNodeModules
        ;

      inherit
        (import ./lib/dependencies.nix {
          inherit lib getDependencies allPackages;
          deps = directDeps;
        })
        depsTree
        ;

      # path of the current package.json
      # needed to check if a package has 'pre-/post-/install-scripts'
      packageJSON = "${src}/package.json";

      packageInfo = builtins.fromJSON (builtins.readFile packageJSON);
      # type:
      #   hasScripts :: Bool
      # build flag shows if package has the pre-pos-install scripts.
      # only sub-packages with those scripts need their own node_modules derivation
      hasScripts = !(packageInfo ? scripts) || (l.any (script: l.any (q: script == q) ["install" "preinstall" "postinstall"]) (b.attrNames packageInfo.scripts));
      needNodeModules = hasScripts || isMain;

      # type: devShellNodeModules :: Derivation
      devShellNodeModules = mkNodeModules {
        isMain = true;
        installMethod = "copy";
        inherit pname version depsTree packageJSON;
      };
      # type: nodeModules :: Derivation
      nodeModules = mkNodeModules {
        inherit installMethod;
        inherit isMain;
        inherit pname version depsTree packageJSON;
      };

      installMethod =
        if isMainPackage name version
        then "copy"
        else "symlink";

      isMain = isMainPackage name version;

      pkg = produceDerivation name (
        pkgs.stdenv.mkDerivation
        rec {
          inherit pname version src;
          inherit nodeSources installMethod isMain;

          # makeWrapper is needed for some current overrides
          nativeBuildInputs = with pkgs; [makeWrapper];
          buildInputs = with pkgs; [jq nodejs python3];

          outputs = ["out" "lib"];

          passthru = {
            inherit nodeModules;
            devShell = import ./lib/devShell.nix {
              inherit nodejs pkgs;
              nodeModules = devShellNodeModules;
            };
          };

          unpackCmd =
            if lib.hasSuffix ".tgz" src
            then "tar --delay-directory-restore -xf $src"
            else null;

          preConfigurePhases = ["skipForeignPlatform"];

          unpackPhase = import ./lib/unpackPhase.nix {};

          # checks platform compatibility (os + arch must match)
          skipForeignPlatform = ''
            # exit code 3 -> the package is incompatible to the current platform
            #  -> Let the build succeed, but don't create node_modules
            ${nodejsBuilder}/bin/checkPlatform  \
            || \
            if [ "$?" == "3" ]; then
              mkdir -p $out
              mkdir -p $lib
              echo "Not compatible with system $system" > $lib/error
              exit 0
            else
              exit 1
            fi
          '';

          configurePhase = l.optionalString needNodeModules ''
            runHook preConfigure

            cp -r ${nodeModules} ./node_modules
            chmod -R +xw node_modules
            patchShebangs ./node_modules

            export NODE_PATH="$NODE_PATH:./node_modules"
            export PATH="$PATH:node_modules/.bin"

            runHook postConfigure
          '';

          # only build the main package
          # deps only get unpacked, installed, patched, etc
          dontBuild = ! isMain;

          buildPhase = ''
            runHook preBuild

            if [ "$(jq '.scripts.build' ./package.json)" != "null" ];
            then
              echo "running npm run build...."
              npm run build
            fi

            runHook postBuild
          '';

          # create package out-paths
          # $out
          # - $out/lib/... -> $lib ...(extracted tgz)
          # - $out/lib/node_modules -> $deps
          # - $out/bin

          # $lib
          # - ... (extracted + install scripts runned)
          installPhase = ''
            runHook preInstall

            if [ ! -n "$isMain" ];
            then
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

            ${nodejsBuilder}/bin/d2nMakeOutputs

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
    devShells =
      {default = devShells.${defaultPackageName};}
      // (
        l.mapAttrs
        (name: version: allPackages.${name}.${version}.devShell)
        packages
      );
  in {
    packages = mainPackages;
    inherit devShells;
  };
}
