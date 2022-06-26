{
  utils,
  callNixWithD2N,
  coreutils,
  ...
}:
utils.writePureShellScriptBin
"index"
[coreutils]
''
  cd $WORKDIR

  usage="usage:
    $0 INDEXER_NAME INDEXER_INPUT"

  if [ "$#" -ne 2 ]; then
    echo "error: wrong number of arguments passed"
    echo "$usage"
    exit 1
  fi

  name=''${1:?"error: please pass the name of the indexer"}
  input=''${2:?"error: please pass indexer input in JSON or JSON file"}

  inputFile="$TMPDIR/input.json"
  if [ -f "$input" ]; then
    ln -s $(realpath $input) $inputFile
  else
    echo "$input" > $inputFile
  fi

  resultBin="$TMPDIR/result"

  ${callNixWithD2N} build -L --keep-failed --out-link $resultBin \
    "dream2nix.indexers.indexers.$name.indexBin"

  $resultBin $inputFile
''
