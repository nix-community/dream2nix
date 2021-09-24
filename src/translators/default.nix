{
  lib,
  callPackage,
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
      translator = callPackage file (args // {
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
      

  buildSystems = dirNames ./.;

  translatorTypes = [ "impure" "ifd" "pure" ];

  # every translator must provide 'bin/translate'
  translatorExec = translatorPkg: "${translatorPkg}/bin/translate";

  # directory names of a given directory
  dirNames = dir: lib.attrNames (lib.filterAttrs (name: type: type == "directory") (builtins.readDir dir));

  # wrapPureTranslator
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
    lib.genAttrs (dirNames ./.) (subsystem:
      lib.genAttrs
        (lib.filter (dir: builtins.pathExists (./. + "/${subsystem}/${dir}")) translatorTypes)
        (transType: function subsystem transType)
    );

  # attrset of: subsystem -> translator-type -> translator
  translators = mkTranslatorsSet (subsystem: type:
    lib.genAttrs (dirNames (./. + "/${subsystem}/${type}")) (translatorName:
      callTranslator subsystem type translatorName (./. + "/${subsystem}/${type}/${translatorName}") {}
    )
  );

  # json file exposing all existing translators to CLI including their special args
  translatorsJsonFile =
    let
      data = lib.mapAttrsRecursiveCond
        (as: !(as ? "translateBin"))
        (k: v:
          v.specialArgs or {}
        )
        translators;
    in
    pkgs.writeText "translators.json" (builtins.toJSON data);

  # filter translators by compatibility for the given input paths
  compatibleTranslators =
    {
      inputDirectories,
      inputFiles,
      translators,
    }:
    let
      compatible = 
        lib.mapAttrs (subsystem: types:
          lib.mapAttrs (type: translators_:
            lib.filterAttrs (name: translator:
              translator ? compatiblePaths
              &&
                translator.compatiblePaths { inherit inputDirectories inputFiles; }
                == { inherit inputDirectories inputFiles; }
            ) translators_
          ) types
        ) translators;
    in
      # purge empty attrsets
      lib.filterAttrsRecursive (k: v: v != {}) (lib.filterAttrsRecursive (k: v: v != {}) compatible);

  # reduce translators by a given selector
  # selector examples:  
  #  - "python"
  #  - "python.impure"
  #  - "python.impure.pip"
  reduceTranslatorsBySelector = selector: translators_:
    let
      split = lib.splitString "." (lib.removeSuffix "." selector);
      selectedSubsystems = if split != [ "" ] then [ (lib.elemAt split 0) ] else buildSystems;
      selectedTypes = if lib.length split > 1 then [ (lib.elemAt split 1) ] else translatorTypes;
      selectedName = if lib.length split > 2 then lib.elemAt split 2 else null;
      compatible =
        lib.mapAttrs (subsystem: types:
          lib.mapAttrs (type: translators:
            lib.filterAttrs (name: translator:
              lib.elem subsystem selectedSubsystems
              && lib.elem type selectedTypes
              && lib.elem selectedName [ name null ]
            ) translators
          ) types
        ) translators_;
    in
      # purge empty attrsets
      lib.filterAttrsRecursive (k: v: v != {}) (lib.filterAttrsRecursive (k: v: v != {}) compatible);


  # return the correct translator bin for the given input paths
  selectTranslator = utils.makeCallableViaEnv (
    {
      selector,  # like 'python.impure' or 'python.impure.pip'
      inputDirectories,  # input paths to translate
      inputFiles,  # input paths to translate
      ...
    }:
    let
      selectedTranslators = reduceTranslatorsBySelector selector translators;
      compatTranslators = compatibleTranslators {
        inherit inputDirectories inputFiles;
        translators = selectedTranslators;
      };
    in
      if selectedTranslators == {} then
        throw "The selector '${selector}' does not select any known translators"
      else if compatTranslators == {} then
        throw ''
          Could not find any translator which is compatible to the given inputs:
            - ${builtins.concatStringsSep "\n  - " (inputDirectories ++ inputFiles)}
        ''
      else
        lib.head (lib.attrValues (lib.head (lib.attrValues (lib.head (lib.attrValues compatTranslators)))))
  );

  getSpecialArgsDefaults = specialArgsDef:
    lib.mapAttrs
      (name: def:
        if def.type == "flag" then
          false
        else
          def.default
      )
      specialArgsDef;

  selectTranslatorJSON = args:
    let
      translator = (selectTranslator args);
      data = {
        SpecialArgsDefaults = getSpecialArgsDefaults (translator.specialArgs or {});
        inherit (translator) subsystem type name;
      };
    in
      builtins.toJSON data;

in
{
  inherit translators translatorsJsonFile selectTranslatorJSON;
}
