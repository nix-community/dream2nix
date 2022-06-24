{
  utils,
  callNixWithD2N,
  coreutils,
  jq,
  ...
}:
utils.writePureShellScriptBin
"fetchSourceShortcut"
[coreutils callNixWithD2N jq]
''
  sourceShortcut=''${1:?"error: you must pass a source shortcut"}
  targetDir=''${2:?"error: you must pass a target directory"}
  targetDir="$(realpath "$targetDir")"

  cd $targetDir

  # translate shortcut to source info
  sourceInfo="sourceInfo.json"
  callNixWithD2N eval --json \
    "dream2nix.fetchers.translateShortcut {shortcut=\"$sourceShortcut\";}" > $sourceInfo
  # update source shortcut with hash
  if [[ "$sourceShortcut" != *"?hash="* ]]; then
    sourceShortcut="$sourceShortcut?hash=$(jq '.hash' -c -r $sourceInfo)"
  fi

  # fetch source
  source="src"
  callNixWithD2N build --out-link $source \
    "dream2nix.fetchers.fetchShortcut {shortcut=\"$sourceShortcut\";}"
''
