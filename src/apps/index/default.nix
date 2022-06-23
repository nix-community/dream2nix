{
  utils,
  callNixWithD2N,
  coreutils,
  ...
}:
utils.writePureShellScriptBin
"index"
[coreutils callNixWithD2N]
''
  cd $WORKDIR

  subsystem=''${1:?"please pass a subsystem"}
  name=''${2:?"please pass the name of the indexer"}
  input=''${3:?"please pass indexer input in JSON or JSON file"}

  inputFile="$TMPDIR/input.json"
  if [ -f "$input" ]; then
    ln -s $(realpath $input) $inputFile
  else
    echo "$input" > $inputFile
  fi

  resultBin="$TMPDIR/result"

  callNixWithD2N build --out-link $resultBin \
    "dream2nix.subsystems.$subsystem.indexers.$name.indexBin"

  $resultBin $inputFile
''
