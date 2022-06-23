{
  dlib,
  lib,
  ...
}: let
  l = lib // builtins;
in {
  type = "impure";

  # disable this as we don't have a builder yet
  disabled = true;

  # the input format is specified in /specifications/translator-call-example.json
  # this script receives a json file including the input paths and specialArgs
  translateBin = {
    # dream2nix utils
    utils,
    dream2nixWithExternals,
    config,
    configFile,
    # nixpkgs deps
    bash,
    coreutils,
    jq,
    nix,
    writeScriptBin,
    ...
  }:
    utils.writePureShellScript
    [
      bash
      coreutils
      jq
      nix
    ]
    ''
      # accroding to the spec, the translator reads the input from a json file
      jsonInput=$1

      # read the json input
      outputFile=$(${jq}/bin/jq '.outputFile' -c -r $jsonInput)
      source=$(${jq}/bin/jq '.source' -c -r $jsonInput)

      tmpBuild=$(mktemp -d)
      cd $tmpBuild
      cp -r $source/* .
      chmod -R +w .
      # This should be in sync with gomod2nix version in flake.lock
      nix run github:tweag/gomod2nix/67f22dd738d092c6ba88e420350ada0ed4992ae8

      nix eval --show-trace --impure --raw --expr "import ${./translate.nix} { \
        dream2nixWithExternals = ${dream2nixWithExternals}; \
        dream2nixConfig = ${configFile}; \
      } ./." > $outputFile
    '';

  # If the translator requires additional arguments, specify them here.
  # There are only two types of arguments:
  #   - string argument (type = "argument")
  #   - boolean flag (type = "flag")
  # String arguments contain a default value and examples. Flags do not.
  extraArgs = {};
}
