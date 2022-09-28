{lib, ...}: let
  l = lib // builtins;
in {
  type = "pure";

  build = {
    lib,
    pkgs,
    stdenv,
    # dream2nix inputs
    externals,
    utils,
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
    b = builtins;

    compiler =
      pkgs
      .haskell
      .packages
      ."${subsystemAttrs.compiler.name}${
        l.stringAsChars (c:
          if c == "."
          then ""
          else c)
        subsystemAttrs.compiler.version
      }"
      or (throw "Could not find ${subsystemAttrs.compiler.name} version ${subsystemAttrs.compiler.version} in pkgs");

    cabalFiles =
      l.mapAttrs
      (key: hash: let
        split = l.splitString "#" key;
      in
        fetchCabalFile {
          inherit hash;
          pname = l.head split;
          version = l.last split;
        })
      subsystemAttrs.cabalHashes or {};

    # packages to export
    packages =
      {default = packages.${defaultPackageName};}
      // (
        lib.mapAttrs
        (name: version: {"${version}" = allPackages.${name}.${version};})
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

    # fetches a cabal file for a given candidate and cabal-file-hash
    fetchCabalFile = {
      hash,
      pname,
      version,
    }:
      pkgs.runCommand
      "${pname}.cabal"
      {
        buildInputs = [
          pkgs.curl
          pkgs.cacert
        ];
        outputHash = hash;
        outputHashAlgo = "sha256";
        outputHashMode = "flat";
      }
      ''
        revision=0
        while true; do
          # will fail if revision does not exist
          curl -f https://hackage.haskell.org/package/${pname}-${version}/revision/$revision.cabal > cabal
          hash=$(sha256sum cabal | cut -d " " -f 1)
          echo "revision $revision: hash $hash; wanted hash: ${hash}"
          if [ "$hash" == "${hash}" ]; then
            mv cabal $out
            break
          fi
          revision=$(($revision + 1))
        done
      '';

    # Generates a derivation for a specific package name + version
    makeOnePackage = name: version: let
      pkg = compiler.mkDerivation (rec {
          pname = l.strings.sanitizeDerivationName name;
          inherit version;
          license = null;

          src = getSource name version;

          isLibrary = true;
          isExecutable = true;
          doCheck = false;
          doBenchmark = false;

          libraryToolDepends = libraryHaskellDepends;
          executableHaskellDepends = libraryHaskellDepends;
          testHaskellDepends = libraryHaskellDepends;
          testToolDepends = libraryHaskellDepends;

          libraryHaskellDepends =
            (with compiler; [
              # TODO: remove these deps / find out why they were missing
              hspec
              QuickCheck
            ])
            ++ (
              map
              (dep: allPackages."${dep.name}"."${dep.version}")
              (getDependencies name version)
            );
        }
        /*
        For all transitive dependencies, overwrite cabal file with the one
        from all-cabal-hashes.
        We want to ensure that the cabal file is the latest revision.
        See: https://github.com/haskell-infra/hackage-trustees/blob/master/revisions-information.md
        */
        // (
          l.optionalAttrs
          (
            (name != defaultPackageName)
            && cabalFiles ? "${name}#${version}"
          )
          {
            preConfigure = ''
              cp ${cabalFiles."${name}#${version}"} ./${name}.cabal
            '';
          }
        )
        # enable tests only for the top-level package
        // (l.optionalAttrs (name == defaultPackageName) {
          doCheck = true;
        }));
    in
      # apply packageOverrides to current derivation
      produceDerivation name pkg;
  in {
    inherit packages;
  };
}
