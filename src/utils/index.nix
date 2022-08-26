{
  lib,
  dlib,
  dream2nixInterface,
  pkgs,
  apps,
  callPackageDream,
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
    indexNames,
    overrideOutputs ? args: {},
    settings ? [],
    inject ? {},
    packageOverrides ? {},
    sourceOverrides ? {},
  }: let
    l = lib // builtins;
    mkApp = script: {
      type = "app";
      program = toString script;
    };

    mkIndexApp = {
      name,
      indexerName ? name,
      input,
    } @ args: let
      input = {outputFile = "${name}/index.json";} // args.input;
      script = pkgs.writers.writeBash "index" ''
        set -e
        inputJson="$(${pkgs.coreutils}/bin/mktemp)"
        echo '${l.toJSON input}' > $inputJson
        mkdir -p $(dirname ${input.outputFile})
        ${apps.index}/bin/index ${indexerName} $inputJson
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
    translateAllApp = let
      allTranslators =
        l.concatStringsSep
        "\n"
        (
          l.mapAttrsToList
          (
            name: translator: ''
              echo "::translating with ${name}::"
              ${translator.program}
              echo "::translated with ${name}::"
            ''
          )
          translateApps
        );
    in
      mkApp (
        pkgs.writers.writeBash "translate-all" ''
          set -e
          ${allTranslators}
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
        translateApps
        // {
          translate = translateAllApp;
        };
    };
  in
    outputs
    // (callPackageDream overrideOutputs {
      inherit mkIndexApp;
      prevOutputs = outputs;
    });
}
