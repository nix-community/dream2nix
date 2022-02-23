{
  dlib,
  lib,
}:

{

  # the input format is specified in /specifications/translator-call-example.json
  # this script receives a json file including the input paths and specialArgs
  translateBin =
    {
      # dream2nix utils
      utils,
      dream2nixWithExternals,

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
        inputDirectory=$(${jq}/bin/jq '.inputDirectories | .[0]' -c -r $jsonInput)

        tmpBuild=$(mktemp -d)
        cd $tmpBuild
        cp -r $inputDirectory/* .
        chmod -R +w .
        # This should be in sync with gomod2nix version in flake.lock
        nix run github:tweag/gomod2nix/67f22dd738d092c6ba88e420350ada0ed4992ae8

        nix eval --show-trace --impure --raw --expr "import ${./translate.nix} ${dream2nixWithExternals} ./." > $outputFile
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
      inputDirectories = lib.filter
        (dlib.containsMatchingFile [ ''go\.sum'' ''go\.mod'' ])
        args.inputDirectories;

      inputFiles = [];
    };


  # If the translator requires additional arguments, specify them here.
  # There are only two types of arguments:
  #   - string argument (type = "argument")
  #   - boolean flag (type = "flag")
  # String arguments contain a default value and examples. Flags do not.
  extraArgs = {};
}
