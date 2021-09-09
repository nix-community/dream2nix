{
  bash,
  jq,
  python,
  writeScriptBin,
  ...
}:

#
# the input format is specified in /specifications/translator-call-example.json

writeScriptBin "translate" ''
  #!${bash}/bin/bash

  set -Eeuo pipefail

  # accroding to the spec, the translator reads the input from a json file
  jsonInput=$1

  # extract the 'inputFiles' field from the json
  inputFiles=$(${jq}/bin/jq '.inputFiles | .[]' -c -r $jsonInput)
  outputFile=$(${jq}/bin/jq '.outputFile' -c -r $jsonInput)

  # pip executable
  pip=${python.pkgs.pip}/bin/pip

  # prepare temporary directory
  tmp=translateTmp
  rm -rf $tmp
  mkdir $tmp

  # download files according to requirements
  $pip download \
    --no-cache \
    --dest $tmp \
    --progress-bar off \
    -r ''${inputFiles/$'\n'/$' -r '}

  # generate the generic lock from the downloaded list of files
  ${python}/bin/python ${./generate-generic-lock.py} $tmp $outputFile

  rm -rf $tmp
''
