# TODO(yusdacra): separate every util function implementation into it's own file and load them automatically
# for now this will have to suffice
{config, ...}: let
  b = builtins;
  l = config.lib // builtins;

  inherit
    (config.pkgs)
    bash
    coreutils
    moreutils
    gitMinimal
    jq
    nix
    pkgs
    python3
    runCommandLocal
    stdenv
    writeScript
    writeScriptBin
    ;

  poetry2nixSemver = import "${config.externalSources.poetry2nix}/semver.nix" {
    inherit (config) lib;
    # copied from poetry2nix
    ireplace = idx: value: list: (
      l.genList
      (i:
        if i == idx
        then value
        else (l.elemAt list i))
      (l.length list)
    );
  };

  impl = rec {
    scripts = {
      formatDreamLock = ./cli/format-dream-lock.py;
      aggregateHashes = ./cli/aggregate-hashes.py;
    };

    toDrv = path: runCommandLocal "some-drv" {} "cp -r ${path} $out";

    # hash the contents of a path via `nix hash path`
    hashPath = algo: path: let
      hashPath = runCommandLocal "hash-${algo}" {} ''
        ${nix}/bin/nix --option experimental-features nix-command hash path ${path} | tr --delete '\n' > $out
      '';
    in
      b.readFile hashPath;

    # hash a file via `nix hash file`
    hashFile = algo: path: let
      hashFile = runCommandLocal "hash-${algo}" {} ''
        ${nix}/bin/nix --option experimental-features nix-command hash file ${path} | tr --delete '\n' > $out
      '';
    in
      b.readFile hashFile;

    # builder to create a shell script that has it's own PATH
    writePureShellScript = availablePrograms: script:
      writeScript "script.sh" ''
        #!${bash}/bin/bash
        set -Eeuo pipefail

        export PATH="${l.makeBinPath availablePrograms}"
        export NIX_PATH=nixpkgs=${pkgs.path}

        TMPDIR=$(${coreutils}/bin/mktemp -d)

        trap '${coreutils}/bin/rm -rf "$TMPDIR"' EXIT

        ${script}
      '';

    # builder to create a shell script that has it's own PATH
    writePureShellScriptBin = binName: availablePrograms: script:
      writeScriptBin binName ''
        #!${bash}/bin/bash
        set -Eeuo pipefail

        export PATH="${l.makeBinPath availablePrograms}"
        export NIX_PATH=nixpkgs=${pkgs.path}

        TMPDIR=$(${coreutils}/bin/mktemp -d)

        trap '${coreutils}/bin/rm -rf "$TMPDIR"' EXIT

        ${script}
      '';

    # TODO is this really needed? Seems to make builds slower, why not unpack + build?
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
          if l.hasSuffix ".tgz" (source.name or "${source}")
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
        config.dlib.calcInvalidationHash {
          inherit project source;
          # TODO: translatorArgs
          translatorArgs = {};
          translator = project.translator;
        },
    } @ args: let
      aggregate = project.aggregate or false;

      translator =
        config.translators."${project.translator}";

      argsJsonFile =
        pkgs.writeText "translator-args.json"
        (l.toJSON (
          args
          // {
            project = l.removeAttrs args.project ["dreamLock"];
            outputFile = project.dreamLockPath;
          }
          // (config.functions.translators.makeTranslatorDefaultArgs translator.extraArgs or {})
          // args.project.subsystemInfo or {}
        ));
      script =
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

          ${translator.finalTranslateBin} ${argsJsonFile}

          # aggregate source hashes
          if [ "${l.toJSON aggregate}" == "true" ]; then
            echo "aggregating all sources to one large FOD"
            dream2nixWithExternals=${config.dream2nixWithExternals} \
            dream2nixConfig=${config.dream2nixConfigFile} \
              python3 ${scripts.aggregateHashes} $dreamLockPath
          fi

          # add invalidationHash to dream-lock.json
          jq '._generic.invalidationHash = "${invalidationHash}"' $dreamLockPath \
            | sponge $dreamLockPath

          # format dream lock
          cat $dreamLockPath \
            | python3 ${scripts.formatDreamLock} \
            | sponge $dreamLockPath

          # validate dream-lock.json against jsonschema
          # setting --base-uri is required to resolve refs to subsystem schemas
          ${python3.pkgs.jsonschema}/bin/jsonschema \
            --instance $dreamLockPath \
            --output pretty \
            --base-uri file:${../../specifications}/ \
            ${../../specifications}/dream-lock-schema.json

          # add dream-lock.json to git
          if git rev-parse --show-toplevel &>/dev/null; then
            echo "adding file to git: $dreamLockPath"
            git add $dreamLockPath || :
          fi
        '';
    in
      script // {passthru = {inherit project;};};
  };
in {
  imports = [
    ./dream-lock.nix
    ./override.nix
    ./translator.nix
    ./toTOML.nix
    ./index
  ];
  config = {
    utils = impl;
  };
}
