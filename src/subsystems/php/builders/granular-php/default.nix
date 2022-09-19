{...}: {
  type = "pure";

  build = {
    lib,
    pkgs,
    stdenv,
    # dream2nix inputs
    externals,
    callPackageDream,
    ...
  }: {
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

    inherit (callPackageDream ../../semver.nix {}) satisfies;

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
      dependencies = getDependencies name version;
      repositories = let
        transform = dep: let
          intoRepository = name: version: root: {
            type = "path";
            url = "${root}/vendor/${name}";
            options = {
              versions = {
                "${name}" = "${version}";
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
          inherit (dep) name;
          value = dep.version;
        })
        dependencies
      ));

      versionString =
        if version == "unknown"
        then "0.0.0"
        else version;

      pkg = stdenv.mkDerivation rec {
        pname = l.strings.sanitizeDerivationName name;
        inherit version;

        src = getSource name version;

        nativeBuildInputs = with pkgs; [
          jq
          composer
        ];
        buildInputs = with pkgs;
          [
            php
            composer
          ]
          ++ map (dep: allPackages."${dep.name}"."${dep.version}")
          dependencies;

        dontConfigure = true;
        buildPhase = ''
          # copy source
          PKG_OUT=$out/lib/vendor/${name}
          mkdir -p $PKG_OUT
          pushd $PKG_OUT
          cp -r ${src}/* .

          # create composer.json if does not exist
          if [ ! -f composer.json ]
          then
            echo {\"name\":\"${name}\"} > composer.json
          fi

          # remove composer.lock if exists
          rm -f composer.lock

          # disable packagist, set path repositories
          mv composer.json composer.json.orig

          cat <<EOF >> $out/repositories.json
          ${repositoriesString}
          EOF
          cat <<EOF >> $out/dependencies.json
          ${dependenciesString}
          EOF

          jq \
            --slurpfile repositories $out/repositories.json \
            --slurpfile dependencies $out/dependencies.json \
            "(.repositories = \$repositories[0]) | \
             (.require = \$dependencies[0]) | \
             (.\"require-dev\" = {}) | \
             (.version = \"${versionString}\")" \
            composer.json.orig > composer.json

          # build
          composer install --no-scripts

          rm -rfv vendor/*/*/vendor

          # cleanup
          popd
          rm $out/repositories.json
          rm $out/dependencies.json
        '';
        installPhase = ''
          pushd $PKG_OUT

          BINS=$(jq -rcM "(.bin // [])[]" composer.json)
          for bin in $BINS
          do
            mkdir -p $out/bin
            pushd $out/bin
            ln -s $PKG_OUT/$bin
            popd
          done

          popd
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
