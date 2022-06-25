{
  # dream2nix deps
  utils,
  callNixWithD2N,
  fetchSourceShortcut,
  coreutils,
  moreutils,
  jq,
  nix,
  python3,
  ...
}:
utils.writePureShellScriptBin
"translate"
[
  coreutils
  moreutils
  fetchSourceShortcut
  callNixWithD2N
  nix
  jq
  python3
]
''
  cd $WORKDIR

  source=''${1:?"error: pass a source shortcut"}
  targetDir=''${2:?"error: please pass a target directory"}
  targetDir="$(realpath "$targetDir")"
  sourceTargetDir=''${translateSourceDir:-"$TMPDIR"}

  mkdir -p $targetDir && cd $targetDir

  export dream2nixConfig="{packagesDir=\"./.\"; projectRoot=\"$targetDir\";}"

  fetchSourceShortcut $source $sourceTargetDir

  resolveDatas="$TMPDIR/resolveData.json"
  callNixWithD2N eval --json "
    let
      data =
        l.map
        (p: let
          resolve = p.passthru.resolve or p.resolve;
        in {
          inherit (resolve.passthru.project) name dreamLockPath;
          drvPath = resolve.drvPath;
        })
        (l.attrValues (l.removeAttrs
          (dream2nix.makeOutputs {source = $sourceTargetDir/src;}).packages
          [\"resolveImpure\"]
        ));
    in
      l.unique data
  " > $resolveDatas

  for resolveData in $(jq '.[]' -c -r $resolveDatas); do
    # extract project data so we can determine where the dream-lock.json will be
    name=$(echo "$resolveData" | jq '.name' -c -r)
    dreamLockPath="$targetDir/$(echo "$resolveData" | jq '.dreamLockPath' -c -r)"
    drvPath=$(echo "$resolveData" | jq '.drvPath' -c -r)

    echo "resolving: $name (lock path: $dreamLockPath)"

    # build the resolve script and run it
    nix build --out-link $TMPDIR/resolve $drvPath
    $TMPDIR/resolve/bin/resolve

    # patch the dream-lock with our source info so the dream-lock works standalone
    sourceInfo="$(jq . -c -r $sourceTargetDir/sourceInfo.json)"
    jqQuery="._generic.sourceRoot = $sourceInfo"
    jq "$jqQuery" -c -r "$dreamLockPath" \
      | python3 ${../cli/format-dream-lock.py} \
      | sponge "$dreamLockPath"

    echo "resolved: $name (lock path: $dreamLockPath)"
  done
''
