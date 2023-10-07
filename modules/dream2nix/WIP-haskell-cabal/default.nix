{
  lib,
  dream2nix,
  config,
  packageSets,
  ...
}: let
  cfg = config.haskell-cabal;

  lock = config.lock.content.haskell-cabal-lock;

  writers = import ../../../pkgs/writers {
    inherit lib;
    inherit
      (config.deps)
      bash
      coreutils
      gawk
      writeScript
      writeScriptBin
      path
      ;
  };

  getNameVer = p: "${p.name}-${p.version}";

  fetchCabalFile = p:
    config.deps.fetchurl {
      url = p.cabal-url;
      sha256 = p.cabal-sha256;
    };

  fetchFromHackage = p:
    config.deps.stdenv.mkDerivation {
      name = "${getNameVer p}-source";

      # NOTE: Cannot use fetchTarball because cabal gives hash before unpacking
      src = config.deps.fetchurl {
        inherit (p) url sha256;
      };

      # We are fetching cabal file separately to match the revision
      # p.url contains only "base" release
      installPhase = ''
        runHook preInstall

        mkdir unpacked
        tar -C unpacked -xf "$src"
        mv unpacked/${getNameVer p} $out
        cp ${fetchCabalFile p} $out/${p.name}.cabal

        runHook postInstall
      '';
    };

  vendorPackage = p: ''
    echo "Vendoring ${fetchFromHackage p}"
    cp -r ${fetchFromHackage p} $VENDOR_DIR/${p.name}
  '';

  vendorPackages =
    builtins.concatStringsSep "\n"
    (lib.mapAttrsToList (_: vendorPackage) lock);
in {
  imports = [
    dream2nix.modules.dream2nix.core
    dream2nix.modules.dream2nix.mkDerivation
    ./interface.nix
  ];

  # TODO: Split build into dependencies and rest
  # TODO: Run tests

  mkDerivation = {
    nativeBuildInputs = [
      config.deps.cabal-install
      config.deps.haskell-compiler
    ];

    configurePhase = ''
      runHook preConfigure

      VENDOR_DIR="$(mktemp -d)"

      if ! test -f ./cabal.project;
      then
        {
          echo "packages: ./."
          echo "optional-packages: $VENDOR_DIR/*/*.cabal"
        } > cabal.project
      else
        echo "optional-packages: $VENDOR_DIR/*/*.cabal" >> cabal.project
      fi

      ${vendorPackages}

      runHook postConfigure
    '';

    # TODO: Add options to enable/disable -j
    buildPhase = ''
      runHook preBuild

      mkdir -p $out/bin

      mkdir -p .cabal
      touch .cabal/config

      HOME=$(pwd) cabal install         \
                  --offline             \
                  --installdir $out/bin \
                  --install-method copy \
                  -j

      runHook postBuild
    '';
  };

  lock.fields.haskell-cabal-lock.script =
    writers.writePureShellScript [
      config.deps.cabal-install
      config.deps.haskell-compiler
      config.deps.coreutils
      (config.deps.python3.withPackages (ps: with ps; [requests]))
    ] ''
      cd $TMPDIR
      cp -r --no-preserve=all ${config.mkDerivation.src}/* .
      cabal update # We need to run update or cabal will fetch invalid cabal hashes
      cabal freeze
      python3 ${./lock.py}
    '';

  deps = {nixpkgs, ...}:
    lib.mapAttrs (_: lib.mkDefault) {
      inherit
        (nixpkgs)
        cabal-install
        python3
        fetchurl
        stdenv
        coreutils
        bash
        gawk
        writeScript
        writeScriptBin
        path
        ;
      haskell-compiler = cfg.compiler;
    };
}
