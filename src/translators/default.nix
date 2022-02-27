{
  coreutils,
  dlib,
  jq,
  lib,
  nix,
  pkgs,

  callPackageDream,
  externals,
  dream2nixWithExternals,
  utils,
  ...
}:

let

  b = builtins;

  l = lib // builtins;

  # transforms V1 translators to V2 translators
  ensureTranslatorV2 = translator:
    let
      version = translator.version or 1;
      cleanedArgs = args: l.removeAttrs args [ "projets" "tree" ];

      upgradedTranslator =
        translator // {
          translate = args:
            l.map
              (proj:
                let
                  dreamLock =
                    translator.translate
                      ((cleanedArgs args) // {
                        source = "${args.source}/${proj.relPath}";
                        name = proj.name;
                      });
                  in
                    dreamLock // {
                      _generic = dreamLock._generic // {
                        location = proj.relPath;
                      };
                    })
              args.projects;
        };
    in
      if version == 2 then
        translator
      else
        upgradedTranslator;

  # transforms V2 translators to V1 translators
  ensureTranslatorV1 = translator:
    let
      version = translator.version or 1;

      downgradeTranslator =
        translator // {
          translate = args:
            l.head
              (translator.translate (args // {
                inherit (args) source;
                tree = dlib.prepareSourceTree { inherit (args) source; };
                projects = [{
                  name = translator.projectName { inherit (args) source; };
                  relPath = "";
                  subsystem = translator.subsystem;
                }];
              }));
        };
    in
      if version == 1 then
        translator
      else
        downgradeTranslator;


  makeTranslatorV2 = translatorModule:
    ensureTranslatorV2 (makeTranslator translatorModule);

  makeTranslatorV1 = translatorModule:
    ensureTranslatorV1 (makeTranslator translatorModule);


  makeTranslator =
    translatorModule:
      let
        translator =
          translatorModule

          # for pure translators
          #   - import the `translate` function
          #   - generate `translateBin`
          // (lib.optionalAttrs (translatorModule ? translate) {
            translate = callPackageDream translatorModule.translate {
              translatorName = translatorModule.name;
            };
            translateBin =
              wrapPureTranslator
              (with translatorModule; [ subsystem type name ]);
          })

          # for impure translators:
          #   - import the `translateBin` function
          // (lib.optionalAttrs (translatorModule ? translateBin) {
            translateBin = callPackageDream translatorModule.translateBin
              {
                translatorName = translatorModule.name;
              };
          });

          # supply calls to translate with default arguments
          translatorWithDefaults = translator // {
            translate = args:
              translator.translate
                (
                  (dlib.translators.getextraArgsDefaults
                    (translator.extraArgs or {}))
                  // args
                );
          };

      in
        translatorWithDefaults;


  translators = dlib.translators.mapTranslators makeTranslatorV1;

  translatorsV2 = dlib.translators.mapTranslators makeTranslatorV2;


  # adds a translateBin to a pure translator
  wrapPureTranslator = translatorAttrPath:
    let
      bin = utils.writePureShellScript
        [
          coreutils
          jq
          nix
        ]
        ''
          jsonInputFile=$(realpath $1)
          outputFile=$(jq '.outputFile' -c -r $jsonInputFile)

          nix eval --show-trace --impure --raw --expr "
              let
                dream2nix = import ${dream2nixWithExternals} {};
                dreamLock =
                  dream2nix.translators.translators.${
                    lib.concatStringsSep "." translatorAttrPath
                  }.translate
                    (builtins.fromJSON (builtins.readFile '''$1'''));
              in
                dream2nix.utils.dreamLock.toJSON
                  # don't use nix to detect cycles, this will be more efficient in python
                  (dreamLock // {
                    _generic = builtins.removeAttrs dreamLock._generic [ \"cyclicDependencies\" ];
                  })
          " | jq > $outputFile
        '';
    in
      bin.overrideAttrs (old: {
        name = "translator-${lib.concatStringsSep "-" translatorAttrPath}";
      });



in
{
  inherit
    translators
    translatorsV2
  ;

  inherit (dlib.translators)
    findOneTranslator
    translatorsForInput
    translatorsForInputRecursive
  ;
}
