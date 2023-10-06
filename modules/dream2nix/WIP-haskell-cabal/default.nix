{ lib
, dream2nix
, config
, packageSets
, ...
}:
let
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

  installPlan = builtins.listToAttrs (builtins.map
    (p: {
      name = p.id;
      value = p;
    })
    lock.install-plan);

  getNameVer = p: "${p.pkg-name}-${p.pkg-version}";

  configuredIds =
    builtins.map (p: p.id)
      (builtins.attrValues
        (lib.attrsets.filterAttrs
          (_: p: p.type == "configured" &&
            p.pkg-src.type == "repo-tar")
          installPlan));

  fetchFromHackage = p:
    let
      cabalFile = config.deps.fetchurl {
        url = p.pkg-cabal-url;
        sha256 = p.pkg-cabal-sha256;
      };
    in

    config.deps.stdenv.mkDerivation {
      name = "${getNameVer p}-source";

      # NOTE: Cannot use fetchTarball because cabal gives hash before unpacking
      src = config.deps.fetchurl {
        url = "${p.pkg-src.repo.uri}package/${p.pkg-name}/${getNameVer p}.tar.gz";
        sha256 = p.pkg-src-sha256;
      };

      installPhase = ''
        runHook preInstall

        mkdir unpacked
        tar -C unpacked -xf "$src"
        mv unpacked/${getNameVer p} $out
        cp ${cabalFile} $out/${p.pkg-name}.cabal

        runHook postInstall
      '';
    };

  vendorPackage = id: ''
    echo "Vendoring ${fetchFromHackage installPlan.${id}}"
    cp -r ${fetchFromHackage installPlan.${id}} ./vendor/${installPlan.${id}.pkg-name}
  '';

  vendorPackages = builtins.concatStringsSep "\n" (builtins.map vendorPackage configuredIds);

in
{
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

      if ! test -f ./cabal.project;
      then
        {
          echo "packages: ./."
          echo "optional-packages: ./vendor/*/*.cabal"
        } > cabal.project
      else
        echo "optional-packages: ./vendor/*/*.cabal" >> cabal.project
      fi
  
      mkdir -p vendor
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
      (config.deps.python3.withPackages (ps: with ps; [ requests ]))
    ] ''
      env -C $(${config.paths.findRoot})/${config.paths.package} python3 ${./lock.py}
    '';

  deps = { nixpkgs, ... }:
    lib.mapAttrs (_: lib.mkDefault) {
      inherit (nixpkgs)
        cabal-install python3 fetchurl stdenv coreutils bash gawk writeScript
        writeScriptBin path;
      haskell-compiler = cfg.compiler;
    };
}
  
