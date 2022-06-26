{
  utils,
  translate,
  coreutils,
  jq,
  ...
}:
utils.writePureShellScriptBin
"translate-index"
[coreutils translate jq]
''
  cd $WORKDIR

  usage="usage:
    $0 INDEX_PATH TARGET_DIR"

  if [ "$#" -ne 2 ]; then
    echo "error: wrong number of arguments"
    echo "$usage"
    exit 1
  fi

  index=''${1:?"error: please pass index file path"}
  index=$(realpath $index)
  targetDir=''${2:?"error: please pass a target directory"}
  targetDir=$(realpath $targetDir)

  for shortcut in $(jq '.[]' -c -r $index); do
    translate "$shortcut" $targetDir \
      || echo "failed to translate \"$shortcut\""
  done
''
