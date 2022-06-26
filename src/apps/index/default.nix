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

  name=''${1:?"please pass the name of the indexer"}
  input=''${2:?"please pass indexer input in JSON or JSON file"}

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
