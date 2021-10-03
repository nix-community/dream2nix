{
  lib,
  callPackageDream,
  pkgs,

  externalSources,
  externals,
  location,
  utils,
  ...
}: 
let

  lib = pkgs.lib;

  callTranslator = subsystem: type: name: file: args: 
    let
      translator = callPackageDream file (args // {
        inherit externals;
        translatorName = name;
      });
      translatorWithBin =
        # if the translator is a pure nix translator,
        # generate a translatorBin for CLI compatibility
        if translator ? translateBin then translator
        else translator // {
          translateBin = wrapPureTranslator [ subsystem type name ];
        };
    in
      translatorWithBin // {
        inherit subsystem type name;
        translate = args:
          translator.translate
            ((getSpecialArgsDefaults translator.specialArgs or {}) // args);
      };
      

  buildSystems = utils.dirNames ./.;

  translatorTypes = [ "impure" "ifd" "pure" ];

  # every translator must provide 'bin/translate'
  translatorExec = translatorPkg: "${translatorPkg}/bin/translate";

  # adds a translateBin to a pure translator
  wrapPureTranslator = translatorAttrPath:
    let
      bin = pkgs.writeScriptBin "translate" ''
        #!${pkgs.bash}/bin/bash

        jsonInputFile=$(realpath $1)
        outputFile=$(${pkgs.jq}/bin/jq '.outputFile' -c -r $jsonInputFile)
        export d2nExternalSources=${externalSources}

        nix eval --impure --raw --expr "
          builtins.toJSON (
            (import ${location} {}).translators.translators.${
              lib.concatStringsSep "." translatorAttrPath
            }.translate 
              (builtins.fromJSON (builtins.readFile '''$1'''))
          )
        " | ${pkgs.jq}/bin/jq > $outputFile
      '';
    in
      bin.overrideAttrs (old: {
        name = "translator-${lib.concatStringsSep "-" translatorAttrPath}";
      });

  # attrset of: subsystem -> translator-type -> (function subsystem translator-type)
  mkTranslatorsSet = function:
    lib.genAttrs (utils.dirNames ./.) (subsystem:
      lib.genAttrs
        (lib.filter (dir: builtins.pathExists (./. + "/${subsystem}/${dir}")) translatorTypes)
        (transType: function subsystem transType)
    );

  # attrset of: subsystem -> translator-type -> translator
  translators = mkTranslatorsSet (subsystem: type:
    lib.genAttrs (utils.dirNames (./. + "/${subsystem}/${type}")) (translatorName:
      callTranslator subsystem type translatorName (./. + "/${subsystem}/${type}/${translatorName}") {}
    )
  );

  # flat list of all translators
  translatorsList = lib.collect (v: v ? translateBin) translators;

  # json file exposing all existing translators to CLI including their special args
  translatorsForInput = utils.makeCallableViaEnv (
    {
      inputDirectories,
      inputFiles,
    }@args:
    lib.forEach translatorsList
      (t: {
        inherit (t)
          name
          specialArgs
          subsystem
          type
        ;
        compatible = t.compatiblePaths args == args;
      })
  );

  # pupulates a translators special args with defaults
  getSpecialArgsDefaults = specialArgsDef:
    lib.mapAttrs
      (name: def:
        if def.type == "flag" then
          false
        else
          def.default
      )
      specialArgsDef;

in
{
  inherit translators translatorsForInput;
}
