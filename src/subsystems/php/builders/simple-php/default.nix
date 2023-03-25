{
  lib,
  pkgs,
  externals,
  ...
}: {
  type = "pure";

  build = {
    ### FUNCTIONS
    # AttrSet -> Bool) -> AttrSet -> [x]
    getCyclicDependencies, # name: version: -> [ {name=; version=; } ]
    getDependencies, # name: version: -> [ {name=; version=; } ]
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
    #   produceDerivation name (mkDerivation {...})
    produceDerivation,
    ...
  } @ args: let
    l = lib // builtins;

    inherit (pkgs.callPackage ../../semver.nix {}) satisfies;

    # php with required extensions
    php =
      if satisfies pkgs.php81.version subsystemAttrs.phpSemver
      then
        pkgs.php81.withExtensions (
          {
            all,
            enabled,
          }:
            l.unique (enabled
              ++ (l.attrValues (l.filterAttrs (e: _: l.elem e subsystemAttrs.phpExtensions) all)))
        )
      else
        l.abort ''
          Error: incompatible php versions.
          Package "${defaultPackageName}" defines required php version:
            "php": "${subsystemAttrs.phpSemver}"
          Using php version "${pkgs.php81.version}" from attribute "pkgs.php81".
        '';
    composer = php.packages.composer;

    # packages to export
    packages =
      {default = packages.${defaultPackageName};}
      // (
        l.mapAttrs
        (name: version: {"${version}" = makePackage name version;})
        args.packages
      );
    devShells =
      {default = devShells.${defaultPackageName};}
      // (
        l.mapAttrs
        (name: version: packages.${name}.${version}.devShell)
        args.packages
      );

    # Unpack dependency
    cleanDependency = name: version:
      pkgs.stdenvNoCC.mkDerivation rec {
        pname = "${l.strings.sanitizeDerivationName name}-source";
        inherit version;
        versionString =
          if version == "unknown"
          then "0.0.0"
          else version;
        src = getSource name version;
        dontConfigure = true;
        buildPhase = ''
          mkdir $out
          cp -r ${src} $out
          if [ ! -f $out/composer.json ]
          then
            echo \
              {\"name\":\"${name}\",\"version\":\"${versionString}\"} \
              > $out/composer.json
          fi
        '';
        dontInstall = true;
        dontFixup = true;
      };

    # Generates a derivation for a specific package name + version
    makePackage = name: version: let
      dependencies = getDependencies name version;
      allDependencies = let
        withKey = x: x // {key = "${x.name} ${x.version}";};
      in
        l.genericClosure {
          startSet = map withKey dependencies;
          operator = dep: map withKey (getDependencies dep.name dep.version);
        };

      intoRepository = dep: {
        type = "path";
        url = "${cleanDependency dep.name dep.version}";
        options = {
          versions = {
            "${l.strings.toLower dep.name}" = "${dep.version}";
          };
          symlink = false;
        };
      };
      repositories = l.flatten (map intoRepository allDependencies);
      repositoriesString =
        l.toJSON
        (repositories ++ [{packagist = false;}]);

      dependenciesString = l.toJSON (l.listToAttrs (
        map (dep: {
          name = l.strings.toLower dep.name;
          value = dep.version;
        })
        dependencies
      ));

      versionString =
        if version == "unknown"
        then "0.0.0"
        else version;

      pkg = pkgs.stdenvNoCC.mkDerivation rec {
        pname = l.strings.sanitizeDerivationName name;
        inherit version;

        src = getSource name version;
        nativeBuildInputs = with pkgs; [
          jq
          composer
          moreutils
        ];
        buildInputs = with pkgs; [
          php
          composer
        ];

        inherit repositoriesString dependenciesString;
        passAsFile = ["repositoriesString" "dependenciesString"];

        unpackPhase = ''
          runHook preUnpack

          mkdir -p $out/lib/vendor/${name}
          cd $out/lib/vendor/${name}

          # copy source
          cp -r ${src}/* .
          chmod -R +w .

          # create composer.json if does not exist
          if [ ! -f composer.json ]; then
            echo "{}" > composer.json
          fi

          # save the original composer.json for reference
          cp composer.json composer.json.orig

          # set name & version
          jq \
            "(.name = \"${name}\") | \
             (.version = \"${versionString}\") | \
             (.extra.patches = {})" \
             composer.json | sponge composer.json

          runHook postUnpack
        '';
        configurePhase = ''
          runHook preConfigure

          # disable packagist, set path repositories
          jq \
            --slurpfile repositories $repositoriesStringPath \
            --slurpfile dependencies $dependenciesStringPath \
            "(.repositories = \$repositories[0]) | \
             (.require = \$dependencies[0]) | \
             (.\"require-dev\" = {})" \
            composer.json | sponge composer.json

          runHook postConfigure
        '';
        composerInstallFlags =
          [
            "--no-scripts"
            "--no-plugins"
          ]
          ++ l.optional (subsystemAttrs.noDev) "--no-dev";
        buildPhase = ''
          runHook preBuild

          # remove composer.lock if exists
          rm -f composer.lock

          # build
          composer install ${l.strings.concatStringsSep " " composerInstallFlags}

          runHook postBuild
        '';
        installPhase = ''
          runHook preInstall

          BINS=$(jq -rcM "(.bin // [])[]" composer.json)
          for bin in $BINS
          do
            mkdir -p $out/bin
            pushd $out/bin
            ln -s $out/lib/vendor/${name}/$bin
            popd
          done

          runHook postInstall
        '';

        passthru.devShell = import ./devShell.nix {
          inherit
            name
            pkg
            php
            composer
            ;
          inherit (pkgs) mkShell;
        };
      };
    in
      # apply packageOverrides to current derivation
      produceDerivation name pkg;
  in {
    inherit packages devShells;
  };
}
