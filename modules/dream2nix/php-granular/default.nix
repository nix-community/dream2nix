{
  config,
  lib,
  dream2nix,
  ...
}: let
  l = lib // builtins;

  cfg = config.php-granular;

  inherit (config.php-composer-lock) dreamLock;

  fetchDreamLockSources =
    import ../../../lib/internal/fetchDreamLockSources.nix
    {inherit lib;};
  getDreamLockSource = import ../../../lib/internal/getDreamLockSource.nix {inherit lib;};
  readDreamLock = import ../../../lib/internal/readDreamLock.nix {inherit lib;};
  hashPath = import ../../../lib/internal/hashPath.nix {
    inherit lib;
    inherit (config.deps) runCommandLocal nix;
  };

  # fetchers
  fetchers = {
    git = import ../../../lib/internal/fetchers/git {
      inherit hashPath;
      inherit (config.deps) fetchgit;
    };
    path = import ../../../lib/internal/fetchers/path {
      inherit hashPath;
    };
  };

  dreamLockLoaded = readDreamLock {inherit dreamLock;};
  dreamLockInterface = dreamLockLoaded.interface;

  inherit (dreamLockInterface) defaultPackageName defaultPackageVersion;

  fetchedSources = fetchDreamLockSources {
    inherit defaultPackageName defaultPackageVersion;
    inherit (dreamLockLoaded.lock) sources;
    inherit fetchers;
  };

  getSource = getDreamLockSource fetchedSources;

  inherit
    (dreamLockInterface)
    getDependencies # name: version: -> [ {name=; version=; } ]
    # Attributes
    subsystemAttrs # attrset
    packageVersions
    ;

  inherit (import ../../../lib/internal/php-semver.nix {inherit lib;}) satisfies;

  selectExtensions = all:
    l.attrValues (
      l.filterAttrs
      (
        e: _:
        #adding xml currently breaks the build of composer
          (e != "xml")
          && (l.elem e ["xml"])
      )
      all
    );

  # php with required extensions
  php =
    if satisfies config.deps.php81.version subsystemAttrs.phpSemver
    then
      # config.deps.php81
      config.deps.php81.withExtensions
      (
        {
          all,
          enabled,
        }:
          l.unique (enabled ++ selectExtensions all)
      )
    else
      l.abort ''
        Error: incompatible php versions.
        Package "${defaultPackageName}" defines required php version:
          "php": "${subsystemAttrs.phpSemver}"
        Using php version "${config.deps.php81.version}" from attribute "config.deps.php81".
      '';
  inherit (php.packages) composer;

  # packages to export
  # packages =
  #   {default = packages.${defaultPackageName};}
  #   // (
  #     lib.mapAttrs
  #     (name: version: {
  #       "${version}" = allPackages.${name}.${version};
  #     })
  #     dreamLockInterface.packages
  #   );
  # devShells =
  #   {default = devShells.${defaultPackageName};}
  #   // (
  #     l.mapAttrs
  #     (name: version: packages.${name}.${version}.devShell)
  #     dreamLockInterface.packages
  #   );

  # Generates a derivation for a specific package name + version
  commonModule = name: version: let
    isTopLevel = dreamLockInterface.packages.name or null == version;

    # name = l.strings.sanitizeDerivationName name;

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
        depRoot = cfg.deps."${dep.name}"."${dep.version}".public;
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
      map
      (dep: {
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
  in
    {config, ...}: {
      imports = [
        dream2nix.modules.dream2nix.mkDerivation
        dream2nix.modules.dream2nix.core
      ];
      deps = {nixpkgs, ...}:
        l.mapAttrs (_: l.mkDefault) {
          inherit
            (nixpkgs)
            jq
            mkShell
            moreutils
            php81
            stdenv
            ;
        };
      public.devShell = import ./devShell.nix {
        inherit
          name
          php
          composer
          ;
        pkg = config.public;
        inherit (config.deps) mkShell;
      };
      php-granular = {
        composerInstallFlags =
          [
            "--no-scripts"
            "--no-plugins"
          ]
          ++ l.optional (subsystemAttrs.noDev || !isTopLevel) "--no-dev";
      };
      env = {
        inherit dependenciesString repositoriesString;
      };
      mkDerivation = {
        src = l.mkDefault (getSource name version);

        nativeBuildInputs = with config.deps; [
          jq
          composer
          moreutils
        ];
        buildInputs = with config.deps;
          [
            php
            composer
          ]
          ++ map (dep: cfg.deps."${dep.name}"."${dep.version}".public)
          dependencies;

        passAsFile = ["repositoriesString" "dependenciesString"];

        unpackPhase = ''
          runHook preUnpack

          mkdir -p $out/lib/vendor/${name}
          cd $out/lib/vendor/${name}

          # copy source
          cp -r ${config.mkDerivation.src}/* .
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
        buildPhase = ''
          runHook preBuild

          # remove composer.lock if exists
          rm -f composer.lock

          # build
          composer install ${l.strings.concatStringsSep " " config.php-granular.composerInstallFlags}

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
      };
    };
in {
  imports = [
    ./interface.nix
    (commonModule defaultPackageName defaultPackageVersion)
  ];
  php-granular.deps =
    lib.mapAttrs
    (name: versions:
      lib.genAttrs
      versions
      (
        version:
        # the submodule for this dependency
        {...}: {
          imports = [
            ./interface.nix
            (commonModule name version)
            cfg.overrideType
            cfg.overrideAll
            (cfg.overrides.${name} or {})
          ];
          inherit name version;
        }
      ))
    packageVersions;
}
