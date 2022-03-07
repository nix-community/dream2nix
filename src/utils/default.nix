{
  bash,
  coreutils,
  dlib,
  fetchzip,
  gitMinimal,
  jq,
  lib,
  nix,
  pkgs,
  python3,
  runCommand,
  stdenv,
  writeScript,
  writeScriptBin,
  # dream2nix inputs
  apps,
  callPackageDream,
  externalSources,
  translators,
  ...
}: let
  b = builtins;
  l = lib // builtins;

  dreamLockUtils = callPackageDream ./dream-lock.nix {};

  overrideUtils = callPackageDream ./override.nix {};

  translatorUtils = callPackageDream ./translator.nix {};
  translatorUtils2 = callPackageDream ./translator2.nix {};

  poetry2nixSemver = import "${externalSources.poetry2nix}/semver.nix" {
    inherit lib;
    # copied from poetry2nix
    ireplace = idx: value: list: (
      lib.genList
      (i:
        if i == idx
        then value
        else (b.elemAt list i))
      (b.length list)
    );
  };
in
  overrideUtils
  // translatorUtils
  // translatorUtils2
  // rec {
    inherit
      (dlib)
      dirNames
      callViaEnv
      identifyGitUrl
      latestVersion
      listDirs
      listFiles
      nameVersionPair
      parseGitUrl
      readTextFile
      recursiveUpdateUntilDepth
      sanitizeDerivationName
      traceJ
      ;

    dreamLock = dreamLockUtils;

    inherit (dreamLockUtils) readDreamLock;

    toDrv = path: runCommand "some-drv" {} "cp -r ${path} $out";

    toTOML = import ./toTOML.nix {inherit lib;};

    # hash the contents of a path via `nix hash path`
    hashPath = algo: path: let
      hashPath = runCommand "hash-${algo}" {} ''
        ${nix}/bin/nix --option experimental-features nix-command hash path ${path} | tr --delete '\n' > $out
      '';
    in
      b.readFile hashPath;

    # hash a file via `nix hash file`
    hashFile = algo: path: let
      hashFile = runCommand "hash-${algo}" {} ''
        ${nix}/bin/nix --option experimental-features nix-command hash file ${path} | tr --delete '\n' > $out
      '';
    in
      b.readFile hashFile;

    # builder to create a shell script that has it's own PATH
    writePureShellScript = availablePrograms: script:
      writeScript "script.sh" ''
        #!${bash}/bin/bash
        set -Eeuo pipefail

        export PATH="${lib.makeBinPath availablePrograms}"
        export NIX_PATH=nixpkgs=${pkgs.path}
        export WORKDIR="$PWD"

        TMPDIR=$(${coreutils}/bin/mktemp -d)
        cd $TMPDIR

        ${script}

        cd
        ${coreutils}/bin/rm -rf $TMPDIR
      '';

    # builder to create a shell script that has it's own PATH
    writePureShellScriptBin = binName: availablePrograms: script:
      writeScriptBin binName ''
        #!${bash}/bin/bash
        set -Eeuo pipefail

        export PATH="${lib.makeBinPath availablePrograms}"
        export NIX_PATH=nixpkgs=${pkgs.path}
        export WORKDIR="$PWD"

        TMPDIR=$(${coreutils}/bin/mktemp -d)
        cd $TMPDIR

        ${script}

        cd
        ${coreutils}/bin/rm -rf $TMPDIR
      '';

    extractSource = {
      source,
      dir ? "",
    }:
      stdenv.mkDerivation {
        name = "${(source.name or "")}-extracted";
        src = source;
        inherit dir;
        phases = ["unpackPhase"];
        dontInstall = true;
        dontFixup = true;
        unpackCmd =
          if lib.hasSuffix ".tgz" source.name
          then ''
            tar --delay-directory-restore -xf $src

            # set executable flag only on directories
            chmod -R +X .
          ''
          else null;
        # sometimes tarballs do not end with .tar.??
        preUnpack = ''
          unpackFallback(){
            local fn="$1"
            tar xf "$fn"
          }

          unpackCmdHooks+=(unpackFallback)
        '';
        postUnpack = ''
          echo postUnpack
          mv "$sourceRoot/$dir" $out
          exit
        '';
      };

    satisfiesSemver = poetry2nixSemver.satisfiesSemver;

    makeTranslateScript = {
      invalidationHash,
      source,
      project,
    } @ args: let
      translator =
        translators.translatorsV2."${project.subsystem}".all."${project.translator}";

      argsJsonFile =
        pkgs.writeText "translator-args.json"
        (l.toJSON
          (args
            // {
              project = l.removeAttrs args.project ["dreamLock"];
              outputFile = project.dreamLockPath;
            }));
    in
      writePureShellScriptBin "resolve"
      [
        coreutils
        jq
        gitMinimal
        nix
        python3
      ]
      ''
        dreamLockPath=${project.dreamLockPath}

        cd $WORKDIR
        ${translator.translateBin} ${argsJsonFile}

        # add invalidationHash to dream-lock.json
        cp $dreamLockPath $dreamLockPath.tmp
        cat $dreamLockPath \
          | jq '._generic.invalidationHash = "${invalidationHash}"' \
          > $dreamLockPath.tmp

        cat $dreamLockPath.tmp \
          | python3 ${../apps/cli2/format-dream-lock.py} \
          > $dreamLockPath

        rm $dreamLockPath.tmp

        # add dream-lock.json to git
        if git rev-parse --show-toplevel &>/dev/null; then
          echo "adding file to git: ${project.dreamLockPath}"
          git add ${project.dreamLockPath}
        fi
      '';

    # a script that produces and dumps the dream-lock json for a given source
    makePackageLockScript = {
      packagesDir,
      source,
      translator,
      translatorArgs,
    }:
      writePureShellScript
      []
      ''
        cd $WORKDIR
        ${apps.cli.program} add ${source} \
          --force \
          --no-default-nix \
          --translator ${translator} \
          --invalidation-hash ${dlib.calcInvalidationHash {
          inherit source translator translatorArgs;
        }} \
          --packages-root $WORKDIR/${packagesDir} \
          ${lib.concatStringsSep " \\\n"
          (lib.mapAttrsToList
            (key: val: "--arg ${key}=${b.toString val}")
            translatorArgs)}
      '';
  }
