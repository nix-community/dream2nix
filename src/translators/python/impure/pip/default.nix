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
  translateBin = writeScriptBin "translate" ''
    #!${bash}/bin/bash

    set -Eeuo pipefail

    # accroding to the spec, the translator reads the input from a json file
    jsonInput=$1

    # extract the 'inputPaths' field from the json
    inputPaths=$(${jq}/bin/jq '.inputPaths | .[]' -c -r $jsonInput)
    outputFile=$(${jq}/bin/jq '.outputFile' -c -r $jsonInput)

    # pip executable
    pip=${python3.pkgs.pip}/bin/pip

    # prepare temporary directory
    tmp=translateTmp
    rm -rf $tmp
    mkdir $tmp

    # download files according to requirements
    $pip download \
      --no-cache \
      --dest $tmp \
      --progress-bar off \
      -r ''${inputPaths/$'\n'/$' -r '}

    # generate the generic lock from the downloaded list of files
    ${python3}/bin/python ${./generate-generic-lock.py} $tmp $outputFile

    rm -rf $tmp
  '';


  # from a given list of paths, this function returns all paths which can be processed by this translator
  compatiblePaths = paths: utils.compatibleTopLevelPaths ".*(requirements).*\\.txt" paths;
}
