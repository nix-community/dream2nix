{
  lib,
  pkgs,
  externals,
  inputs,
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

    phpPackages = l.attrValues inputs.phps.packages.x86_64-linux;
    phpPackage = let
      matchingVersions = l.filter (phpAttrs: satisfies phpAttrs.version subsystemAttrs.phpSemver) phpPackages;
    in
      if matchingVersions == []
      then
        l.abort ''
          Error: incompatible php versions.
          Package "${defaultPackageName}" defines required php version:
            "php": "${subsystemAttrs.phpSemver}"
          No matching php version was found in known versions: ${toString (l.map (attrs: attrs.version) phpPackages)}.
        ''
      else l.head matchingVersions;

    # php with required extensions
    php = phpPackage.withExtensions (
      {
        all,
        enabled,
      }:
        l.unique (enabled
          ++ (l.attrValues (l.filterAttrs (e: _: l.elem e subsystemAttrs.phpExtensions) all)))
    );
    composer = phpPackage.packages.composer;

    # packages to export
    packages =
      {default = packages.${defaultPackageName};}
      // (
        lib.mapAttrs
        (name: version: {
          "${version}" = allPackages.${name}.${version};
        })
        args.packages
      );
    devShells =
      {default = devShells.${defaultPackageName};}
      // (
        l.mapAttrs
        (name: version: packages.${name}.${version}.devShell)
        args.packages
      );

    # manage packages in attrset to prevent duplicated evaluation
    allPackages =
      lib.mapAttrs
      (name: versions:
        lib.genAttrs
        versions
        (version: makeOnePackage name version))
      packageVersions;

    # Generates a derivation for a specific package name + version
    makeOnePackage = name: version: let
      isTopLevel = packages ? name && packages.name == version;

      dependencies = getDependencies name version;
      repositories = let
        transform = dep: let
          intoRepository = name: version: root: {
            type = "path";
            url = "${root}/vendor/${name}";
            options = {
              versions = {
                "${l.strings.toLower name}" = "${version}";
              };
              symlink = false;
            };
          };
          getAllSubdependencies = deps: let
            getSubdependencies = dep: let
              subdeps = getDependencies dep.name dep.version;
            in
              l.flatten ([dep] ++ (getAllSubdependencies subdeps));
          in
            l.flatten (map getSubdependencies deps);
          depRoot = allPackages."${dep.name}"."${dep.version}";
          direct = intoRepository dep.name dep.version "${depRoot}/lib";
          transitive =
            map
            (subdep: intoRepository subdep.name subdep.version "${depRoot}/lib/vendor/${dep.name}")
            (getAllSubdependencies (getDependencies dep.name dep.version));
        in
          [direct] ++ transitive;
      in
        l.flatten (map transform dependencies);
      repositoriesString =
        l.toJSON
        (repositories ++ [{packagist = false;}]);
      dependenciesString = l.toJSON (l.listToAttrs (
        map (dep: {
          name = l.strings.toLower dep.name;
          value = dep.version;
        })
        (dependencies
          ++ l.optional (subsystemAttrs.composerPluginApiSemver ? "${name}@${version}")
          {
            name = "composer-plugin-api";
            version = subsystemAttrs.composerPluginApiSemver."${name}@${version}";
          })
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
        buildInputs = with pkgs;
          [
            php
            composer
          ]
          ++ map (dep: allPackages."${dep.name}"."${dep.version}")
          dependencies;

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
             (.version = \"${versionString}\")" \
             composer.json | sponge composer.json

          runHook postUnpack
        '';
        patchPhase = ''
          runHook prePatch

          # fixup composer.json
          jq \
             "(.extra.patches = {})" \
             composer.json | sponge composer.json

          runHook postPatch
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
          ++ l.optional (subsystemAttrs.noDev || !isTopLevel) "--no-dev";
        buildPhase = ''
          runHook preBuild

          # remove composer.lock if exists
          rm -f composer.lock

          # build
          composer install ${l.strings.concatStringsSep " " composerInstallFlags}

          runHook postBuild

          rm -rfv vendor/*/*/vendor
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
