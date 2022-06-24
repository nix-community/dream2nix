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

  index=''${1:?"please pass index file path"}
  index=$(realpath $index)
  targetDir=''${2:?"please pass a target directory"}
  targetDir=$(realpath $targetDir)

  for shortcut in $(jq '.[]' -c -r $index); do
    translate "$shortcut" $targetDir \
      || echo "failed to translate \"$shortcut\""
  done
''
