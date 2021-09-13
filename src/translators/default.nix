{ pkgs }: 
let

  lib = pkgs.lib;

  callPackage = pkgs.callPackage;

  # every translator must provide 'bin/translate'
  translatorExec = translatorPkg: "${translatorPkg}/bin/translate";

  dirNames = dir: lib.attrNames (lib.filterAttrs (name: type: type == "directory") (builtins.readDir dir));

  translators =
    lib.genAttrs (dirNames ./.) (subsystem:
      lib.genAttrs
        (lib.filter (dir: builtins.pathExists (./. + "/${subsystem}/${dir}")) [ "impure" "ifd" "pure-nix" ])
        (transType:
          lib.genAttrs (dirNames (./. + "/${subsystem}/${transType}")) (translatorName:
            callPackage (./. + "/${subsystem}/${transType}/${translatorName}") {}
        )
      )
    );

  # dump the list of available translators to a json file so they can be listed in the CLI
  translatorsJsonFile = pkgs.writeText "translators.json" (builtins.toJSON (
    lib.genAttrs (dirNames ./.) (subsystem:
      lib.genAttrs 
        (lib.filter (dir: builtins.pathExists (./. + "/${subsystem}/${dir}")) [ "impure" "ifd" "pure-nix" ])
        (transType:
          dirNames (./. + "/${subsystem}/${transType}")
        )
    )
  ));

in
{
  inherit translators translatorsJsonFile;
}
