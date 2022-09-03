{
  lib,
  dlib,
  dream2nixInterface,
  pkgs,
  apps,
  callPackageDream,
  utils,
  ...
} @ topArgs: let
  l = lib // builtins;
in rec {
  generatePackagesFromLocksTree = {
    source ? throw "pass source",
    tree ? dlib.prepareSourceTree {inherit source;},
    settings ? [],
    inject ? {},
    packageOverrides ? {},
    sourceOverrides ? {},
  }: let
    findDreamLocks = tree:
      (
        let
          dreamLockFile = tree.files."dream-lock.json" or {};
        in
          l.optional
          (
            dreamLockFile
            ? content
            && l.stringLength dreamLockFile.content > 0
          )
          dreamLockFile.jsonContent
      )
      ++ (
        l.flatten (
          l.map findDreamLocks
          (l.attrValues tree.directories)
        )
      );
    dreamLocks = findDreamLocks tree;
    makePackagesForDreamLock = dreamLock:
      (dream2nixInterface.makeOutputsForDreamLock {
        inherit
          dreamLock
          inject
          packageOverrides
          sourceOverrides
          ;
      })
      .packages;
  in
    l.foldl'
    (acc: el: acc // el)
    {}
    (l.map makePackagesForDreamLock dreamLocks);
  makeOutputsForIndexes = {
    source,
    indexes,
    settings ? [],
    inject ? {},
    packageOverrides ? {},
    sourceOverrides ? {},
  }: let
    l = lib // builtins;
    indexNames = l.attrNames indexes;

    mkApp = script: {
      type = "app";
      program = toString script;
    };

    mkIndexApp = name: input: let
      inputFinal = {outputFile = "${name}/index.json";} // input;
      script = pkgs.writers.writeBash "index" ''
        set -e
        inputJson="$(${pkgs.coreutils}/bin/mktemp)"
        echo '${l.toJSON inputFinal}' > $inputJson
        mkdir -p $(dirname ${inputFinal.outputFile})
        ${apps.index}/bin/index ${name} $inputJson
      '';
    in
      mkApp script;
    mkTranslateApp = name:
      mkApp (
        pkgs.writers.writeBash "translate-${name}" ''
          set -e
          ${apps.translate-index}/bin/translate-index \
            ${name}/index.json ${name}/locks
        ''
      );
    mkCiJobApp = name: input:
      mkApp (
        utils.writePureShellScript
        (with pkgs; [
          coreutils
          git
          gnugrep
          openssh
        ])
        ''
          flake=$(cat flake.nix)
          flakeLock=$(cat flake.lock)
          set -x
          git fetch origin data || :
          git checkout origin/data || :
          git branch -D data || :
          git checkout -b data
          # the flake should always be the one from the current main branch
          rm -rf ./*
          echo "$flake" > flake.nix
          echo "$flakeLock" > flake.lock
          ${(mkIndexApp name input).program}
          ${(mkTranslateApp name).program}
          git add .
          git commit -m "automatic update - $(date --rfc-3339=seconds)"
        ''
      );
    translateApps = l.listToAttrs (
      l.map
      (
        name:
          l.nameValuePair
          "translate-${name}"
          (mkTranslateApp name)
      )
      indexNames
    );
    indexApps = l.listToAttrs (
      l.mapAttrsToList
      (
        name: input:
          l.nameValuePair
          "index-${name}"
          (mkIndexApp name input)
      )
      indexes
    );
    ciJobApps = l.listToAttrs (
      l.mapAttrsToList
      (
        name: input:
          l.nameValuePair
          "ci-job-${name}"
          (mkCiJobApp name input)
      )
      indexes
    );
    ciJobAllApp = mkApp (
      utils.writePureShellScript
      (with pkgs; [
        coreutils
        git
        gnugrep
        openssh
      ])
      ''
        flake=$(cat flake.nix)
        flakeLock=$(cat flake.lock)
        set -x
        git fetch origin data || :
        git checkout origin/data || :
        git branch -D data || :
        git checkout -b data
        # the flake should always be the one from the current main branch
        rm -rf ./*
        echo "$flake" > flake.nix
        echo "$flakeLock" > flake.lock
        ${lib.concatStringsSep "\n" (l.mapAttrsToList (_: app: app.program) indexApps)}
        ${lib.concatStringsSep "\n" (l.mapAttrsToList (_: app: app.program) translateApps)}
        git add .
        git commit -m "automatic update - $(date --rfc-3339=seconds)"
      ''
    );

    mkIndexOutputs = name: let
      src = "${toString source}/${name}/locks";
    in
      if l.pathExists src
      then
        l.removeAttrs
        (generatePackagesFromLocksTree {
          source = src;
          inherit
            settings
            inject
            packageOverrides
            sourceOverrides
            ;
        })
        ["default"]
      else {};

    allPackages =
      l.foldl'
      (acc: el: acc // el)
      {}
      (l.map mkIndexOutputs indexNames);

    outputs = {
      packages = allPackages;
      apps =
        {ci-job-all = ciJobAllApp;}
        // indexApps
        // translateApps
        // ciJobApps;
    };
  in
    outputs;
}
