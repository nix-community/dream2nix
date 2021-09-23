{
  # dream2nix utils
  utils,

  # nixpkgs dependenies
  bash,
  jq,
  lib,
  writeScriptBin,
  ...
}:

{

  # the input format is specified in /specifications/translator-call-example.json
  # this script receives a json file including the input paths and specialArgs
  translateBin = writeScriptBin "translate" ''
    #!${bash}/bin/bash

    set -Eeuo pipefail

    # accroding to the spec, the translator reads the input from a json file
    jsonInput=$1

    # read the json input
    outputFile=$(${jq}/bin/jq '.outputFile' -c -r $jsonInput)
    inputDirectories=$(${jq}/bin/jq '.inputDirectories | .[]' -c -r $jsonInput)
    inputFiles=$(${jq}/bin/jq '.inputFiles | .[]' -c -r $jsonInput)

    # TODO:
    # read input files/dirs and produce a json file at $outputFile
    # containing the dream lock similar to /specifications/dream-lock-example.json
  '';


  # From a given list of paths, this function returns all paths which can be processed by this translator.
  # This allows the framework to detect if the translator is compatible with the given inputs
  # to automatically select the right translator.
  compatiblePaths =
    {
      inputDirectories,
      inputFiles,
    }@args:
    {
      inputDirectories = [];
      # TODO: insert regex here that matches valid input file names
      # examples:
      #   - ".*(requirements).*\\.txt"
      #   - ".*(package-lock\\.json)"
      inputFiles = lib.filter (f: builtins.match "# TODO: your regex" f != null) args.inputFiles;
    };


  # If the translator requires additional arguments, specify them here.
  # There are only two types of arguments:
  #   - string argument (type = "argument")
  #   - boolean flag (type = "flag")
  # String arguments contain a default value and examples. Flags do not.
  specialArgs = {

    # Example: string option
    # This will be exposed by the translate CLI command as --arg_the-answer
    the-answer = {
      default = "42";
      description = "The Answer to the Ultimate Question of Life";
      examples = [
        "0"
        "1234"
      ];
      type = "argument";
    };

    # Example: boolean option
    # This will be exposed by the translate CLI command as --flag_example-flag
    # The default value of boolean flags is always false
    flat-earth = {
      description = "Is the earth flat";
      type = "flag";
    };

  };
}
