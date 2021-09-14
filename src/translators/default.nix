{
  pkgs,

  externalSources,
  externals,
  location,
}: 
let

  lib = pkgs.lib;

  callPackage = pkgs.callPackage;
  callTranslator = file: name: args: pkgs.callPackage file (args // {
    inherit externals;
    translatorName = name;
  });

  # every translator must provide 'bin/translate'
  translatorExec = translatorPkg: "${translatorPkg}/bin/translate";

  # directory names of a given directory
  dirNames = dir: lib.attrNames (lib.filterAttrs (name: type: type == "directory") (builtins.readDir dir));

  # wrapPureTranslator
  wrapPureTranslator = translatorAttrPath: pkgs.writeScriptBin "translate" ''
    #!${pkgs.bash}/bin/bash

    echo wrapPureTranslator

    jsonInputFile=$1
    outputFile=$(${pkgs.jq}/bin/jq '.outputFile' -c -r $jsonInputFile)
    export d2nExternalSources=${externalSources}

    nix eval --impure --raw --expr "
      builtins.toJSON (
        (import ${location} {}).translators.translatorsInternal.${
          lib.concatStringsSep "." translatorAttrPath
        }.translate 
          (builtins.fromJSON (builtins.readFile '''$1'''))
      )
    " | ${pkgs.jq}/bin/jq > $outputFile
  '';

  mkTranslatorsSet = function:
    lib.genAttrs (dirNames ./.) (subsystem:
      lib.genAttrs
        (lib.filter (dir: builtins.pathExists (./. + "/${subsystem}/${dir}")) [ "impure" "ifd" "pure" ])
        (transType: function subsystem transType)
    );

  
  translators = mkTranslatorsSet (subsystem: type:
    lib.genAttrs (dirNames (./. + "/${subsystem}/${type}")) (translatorName:
      if type == "impure" then
        callTranslator (./. + "/${subsystem}/${type}/${translatorName}") translatorName {}
      else
        wrapPureTranslator [ subsystem type translatorName ]
    )
  );

  translatorsInternal = mkTranslatorsSet (subsystem: type:
    lib.genAttrs (dirNames (./. + "/${subsystem}/${type}")) (translatorName:
      callTranslator (./. + "/${subsystem}/${type}/${translatorName}") translatorName {}
    )
  );

  translatorsJsonFile =
    pkgs.writeText
      "translators.json"
      (builtins.toJSON
        (mkTranslatorsSet (subsystem: type:
          dirNames (./. + "/${subsystem}/${type}")
        )
      ));

in
{
  inherit translators translatorsInternal translatorsJsonFile;
}
