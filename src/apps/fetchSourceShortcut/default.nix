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

  cd $WORKDIR

  # translate shortcut to source info
  sourceInfo="sourceInfo.json"
  callNixWithD2N eval --json \
    "dream2nix.fetchers.translateShortcut {shortcut=\"$sourceShortcut\";}" > $sourceInfo
  # update source shortcut with hash
  sourceShortcut="$sourceShortcut?hash=$(jq '.hash' -c -r $sourceInfo)"

  # fetch source
  source="src"
  callNixWithD2N build --out-link $source \
    "dream2nix.fetchers.fetchShortcut {shortcut=\"$sourceShortcut\";}"
''
