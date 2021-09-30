{
  # dream2nix utils
  utils,

  bash,
  jq,
  lib,
  python3,
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
    pythonAttr=$(${jq}/bin/jq '.pythonAttr' -c -r $jsonInput)
    inputDirectories=$(${jq}/bin/jq '.inputDirectories | .[]' -c -r $jsonInput)
    inputFiles=$(${jq}/bin/jq '.inputFiles | .[]' -c -r $jsonInput)

    # build python and pip executables
    tmpBuild=$(mktemp -d)
    cd $tmpBuild
    nix build --impure --expr "(import <nixpkgs> {}).$pythonAttr" -o python
    nix build --impure --expr "(import <nixpkgs> {}).$pythonAttr.pkgs.pip" -o pip
    cd -

    # prepare temporary directory
    tmp=$(mktemp -d)

    # download files according to requirements
    $tmpBuild/pip/bin/pip download \
      --no-cache \
      --dest $tmp \
      --progress-bar off \
      -r ''${inputFiles/$'\n'/$' -r '}

    # generate the generic lock from the downloaded list of files
    $tmpBuild/python/bin/python ${./generate-dream-lock.py} $tmp $jsonInput

    rm -rf $tmp $tmpBuild
  '';


  # from a given list of paths, this function returns all paths which can be processed by this translator
  compatiblePaths =
    {
      inputDirectories,
      inputFiles,
    }@args:
    {
      inputDirectories = [];
      inputFiles = lib.filter (f: builtins.match ".*(requirements).*\\.txt" f != null) args.inputFiles;
    };

  # define special args and provide defaults
  specialArgs = {
    
    # the python attribute
    pythonAttr = {
      default = "python3${lib.elemAt (lib.splitString "." python3.version) 1}";
      description = "python version to translate for";
      examples = [
        "python27"
        "python39"
        "python310"
      ];
      type = "argument";
    };

    main = {
      description = "name of the main package";
      examples = [
        "some-package"
      ];
      type = "argument";
    };

    application = {
      description = "build application instead of package";
      type = "flag";
    };

  };
}
