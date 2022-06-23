{
  bash,
  coreutils,
  moreutils,
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
  dream2nixWithExternals,
  externalSources,
  subsystems,
  config,
  ...
}: let
  b = builtins;
  l = lib // builtins;

  dreamLockUtils = callPackageDream ./dream-lock.nix {};

  overrideUtils = callPackageDream ./override.nix {};

  translatorUtils = callPackageDream ./translator.nix {};

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
      name ? null,
    } @ args:
      stdenv.mkDerivation {
        name = "${(args.name or source.name or "")}-extracted";
        src = source;
        inherit dir;
        phases = ["unpackPhase"];
        dontInstall = true;
        dontFixup = true;
        # Allow to access the original output of the FOD.
        # Some builders like python require the original archive.
        passthru.original = source;
        unpackCmd =
          if lib.hasSuffix ".tgz" (source.name or "${source}")
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
      source,
      project,
      invalidationHash ?
        dlib.calcInvalidationHash {
          inherit project source;
          # TODO: translatorArgs
          translatorArgs = {};
          translator = project.translator;
        },
    } @ args: let
      aggregate = project.aggregate or false;

      translator =
        subsystems."${project.subsystem}".translators."${project.translator}";

      argsJsonFile =
        pkgs.writeText "translator-args.json"
        (l.toJSON (
          args
          // {
            project = l.removeAttrs args.project ["dreamLock"];
            outputFile = project.dreamLockPath;
          }
          // (dlib.translators.getextraArgsDefaults translator.extraArgs or {})
          // args.project.subsystemInfo
        ));
    in
      writePureShellScriptBin "resolve"
      [
        moreutils
        coreutils
        jq
        gitMinimal
        nix
        python3
      ]
      ''
        dreamLockPath="${project.dreamLockPath}"

        cd $WORKDIR
        ${translator.translateBin} ${argsJsonFile}

        # aggregate source hashes
        if [ "${l.toJSON aggregate}" == "true" ]; then
          echo "aggregating all sources to one large FOD"
          dream2nixWithExternals=${dream2nixWithExternals} \
          dream2nixConfig=${l.toFile "dream2nix-config.json" (l.toJSON config)} \
            python3 ${../apps/cli}/aggregate-hashes.py $dreamLockPath
        fi

        # add invalidationHash to dream-lock.json
        jq '._generic.invalidationHash = "${invalidationHash}"' $dreamLockPath \
          | sponge $dreamLockPath

        # format dream lock
        cat $dreamLockPath \
          | python3 ${../apps/cli/format-dream-lock.py} \
          | sponge $dreamLockPath

        # add dream-lock.json to git
        if git rev-parse --show-toplevel &>/dev/null; then
          echo "adding file to git: $dreamLockPath"
          git add $dreamLockPath
        fi
      '';
  }
