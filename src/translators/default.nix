{ pkgs }: 
let

  callPackage = pkgs.callPackage;

  # every translator must provide 'bin/translate'
  translatorExec = translatorPkg: "${translatorPkg}/bin/translate";

  # the list of all available translators
  translators = {

    python = {

      # minimal POC python translator using pip. Type: 'external'
      external-pip-python36 = callPackage ./python/external-pip { python = pkgs.python36; };
      external-pip-python37 = callPackage ./python/external-pip { python = pkgs.python37; };
      external-pip-python38 = callPackage ./python/external-pip { python = pkgs.python38; };
      external-pip-python39 = callPackage ./python/external-pip { python = pkgs.python39; };
      external-pip-python310 = callPackage ./python/external-pip { python = pkgs.python310; };

      # TODO: add more translators

    };
  };

  # Put all translator executables in a json file.
  # This will allow the cli to call the translators of different build systems
  # in a standardised way
  translatorsJsonFile = callPackage ({ bash, lib, runCommand, ... }:
    runCommand
      "translators.json"
      {
        buildInputs = lib.flatten 
          (
            lib.mapAttrsToList
              (subsystem: translators:
                lib.attrValues translators
              )
              translators
          );
      }
      # 'unsafeDiscardStringContext' is safe in thix context because all store paths are declared as buildInputs
      ''
        #!${bash}/bin/bash
        cp ${builtins.toFile "translators.json" (builtins.unsafeDiscardStringContext (builtins.toJSON translators))} $out
      ''
  ) {};

in

# the unified translator cli
callPackage ({ python3, writeScriptBin, ... }:
  writeScriptBin "cli" ''
    translatorsJsonFile=${translatorsJsonFile} ${python3}/bin/python ${./cli.py} "$@"
  ''
) {}
