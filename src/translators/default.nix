{
  coreutils,
  dlib,
  jq,
  lib,
  nix,
  pkgs,
  python3,
  callPackageDream,
  externals,
  dream2nixWithExternals,
  utils,
  ...
}: let
  b = builtins;

  l = lib // builtins;

  # transforms V1 translators to V2 translators
  ensureTranslatorV2 = translator: let
    version = translator.version or 1;
    cleanedArgs = args: l.removeAttrs args ["project" "tree"];

    upgradedTranslator =
      translator
      // (lib.optionalAttrs (translator ? translate) {
        translate = args: let
          dreamLock =
            translator.translate
            ((cleanedArgs args)
              // {
                source = "${args.source}/${args.project.relPath}";
                name = args.project.name;
              });
        in
          dreamLock
          // {
            _generic =
              dreamLock._generic
              // {
                location = args.project.relPath;
              };
          };
      });

    finalTranslator =
      if version == 2
      then translator
      else upgradedTranslator;
  in
    finalTranslator
    // (lib.optionalAttrs (finalTranslator ? translate) {
      translateBin =
        wrapPureTranslator2
        (with translator; [subsystem type name]);
      # ensure `tree` is passed
      translate = args:
        finalTranslator.translate (args
          // {
            tree =
              args.tree or (dlib.prepareSourceTree {inherit (args) source;});
          });
    });

  # transforms V2 translators to V1 translators
  ensureTranslatorV1 = translator: let
    version = translator.version or 1;

    downgradeTranslator =
      translator
      // (lib.optionalAttrs (translator ? translate) {
        translate = args:
          translator.translate (args
            // {
              inherit (args) source;
              tree = dlib.prepareSourceTree {inherit (args) source;};
              project = {
                name = translator.projectName {inherit (args) source;};
                relPath = "";
                subsystem = translator.subsystem;
              };
            });
      });

    finalTranslator =
      if version == 1
      then translator
      else downgradeTranslator;
  in
    finalTranslator;

  makeTranslatorV2 = translatorModule:
    ensureTranslatorV2 (makeTranslator translatorModule);

  makeTranslatorV1 = translatorModule:
    ensureTranslatorV1 (makeTranslator translatorModule);

  makeTranslator = translatorModule: let
    translator =
      translatorModule
      # for pure translators
      #   - import the `translate` function
      #   - generate `translateBin`
      // (lib.optionalAttrs (translatorModule ? translate) {
        translate = let
          translateOriginal = callPackageDream translatorModule.translate {
            translatorName = translatorModule.name;
          };
        in
          args:
            translateOriginal
            (
              (dlib.translators.getextraArgsDefaults
                (translatorModule.extraArgs or {}))
              // args
            );
        translateBin =
          wrapPureTranslator
          (with translatorModule; [subsystem type name]);
      })
      # for impure translators:
      #   - import the `translateBin` function
      // (lib.optionalAttrs (translatorModule ? translateBin) {
        translateBin =
          callPackageDream translatorModule.translateBin
          {
            translatorName = translatorModule.name;
          };
      });
  in
    translator;

  translators = dlib.translators.mapTranslators makeTranslatorV1;

  translatorsV2 = dlib.translators.mapTranslators makeTranslatorV2;

  # adds a translateBin to a pure translator
  wrapPureTranslator2 = translatorAttrPath: let
    bin =
      utils.writePureShellScript
      [
        coreutils
        jq
        nix
        python3
      ]
      ''
        jsonInputFile=$(realpath $1)
        outputFile=$WORKDIR/$(jq '.outputFile' -c -r $jsonInputFile)

        cd $WORKDIR
        mkdir -p $(dirname $outputFile)

        nix eval \
          --option experimental-features "nix-command flakes"\
          --show-trace --impure --raw --expr "
          let
            dream2nix = import ${dream2nixWithExternals} {};

            translatorArgs =
              (builtins.fromJSON
                  (builtins.unsafeDiscardStringContext (builtins.readFile '''$1''')));

            dreamLock =
              dream2nix.translators.translatorsV2.${
          lib.concatStringsSep "." translatorAttrPath
        }.translate
                translatorArgs;
          in
            dream2nix.utils.dreamLock.toJSON
              # don't use nix to detect cycles, this will be more efficient in python
              (dreamLock // {
                _generic = builtins.removeAttrs dreamLock._generic [ \"cyclicDependencies\" ];
              })
        " | python3 ${../apps/cli2/format-dream-lock.py} > $outputFile
      '';
  in
    bin.overrideAttrs (old: {
      name = "translator-${lib.concatStringsSep "-" translatorAttrPath}";
    });

  # adds a translateBin to a pure translator
  wrapPureTranslator = translatorAttrPath: let
    bin =
      utils.writePureShellScript
      [
        coreutils
        jq
        nix
        python3
      ]
      ''
        jsonInputFile=$(realpath $1)
        outputFile=$(jq '.outputFile' -c -r $jsonInputFile)

        cd $WORKDIR
        mkdir -p $(dirname $outputFile)

        nix eval \
          --option experimental-features "nix-command flakes"\
          --show-trace --impure --raw --expr "
          let
            dream2nix = import ${dream2nixWithExternals} {};

            translatorArgs =
              (builtins.fromJSON
                  (builtins.unsafeDiscardStringContext (builtins.readFile '''$1''')));

            dreamLock =
              dream2nix.translators.translators.${
          lib.concatStringsSep "." translatorAttrPath
        }.translate
                translatorArgs;
          in
            dream2nix.utils.dreamLock.toJSON
              # don't use nix to detect cycles, this will be more efficient in python
              (dreamLock // {
                _generic = builtins.removeAttrs dreamLock._generic [ \"cyclicDependencies\" ];
              })
        " | python3 ${../apps/cli2/format-dream-lock.py} > $outputFile
      '';
  in
    bin.overrideAttrs (old: {
      name = "translator-${lib.concatStringsSep "-" translatorAttrPath}";
    });
in {
  inherit
    translators
    translatorsV2
    ;

  inherit
    (dlib.translators)
    findOneTranslator
    translatorsForInput
    translatorsForInputRecursive
    ;
}
