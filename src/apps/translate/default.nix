{
  # dream2nix deps
  utils,
  callNixWithD2N,
  fetchSourceShortcut,
  coreutils,
  moreutils,
  jq,
  nix,
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
]
''
  source=''${1:?"error: pass a source shortcut"}
  targetDir=''${2:?"error: please pass a target directory"}
  targetDir="$(realpath "$targetDir")"
  sourceTargetDir=''${translateSourceDir:-"$TMPDIR"}

  mkdir -p $targetDir && cd $targetDir

  export dream2nixConfig="{packagesDir=\"./.\"; projectRoot=\"$targetDir\";}"

  fetchSourceShortcut $source $sourceTargetDir

  resolveDatas="$TMPDIR/resolveData.json"
  callNixWithD2N eval --json "
    b.map
    (p: let
      resolve = p.passthru.resolve or p.resolve;
    in {
      inherit (resolve.passthru.project) name relPath;
      drvPath = resolve.drvPath;
    })
    (b.attrValues (b.removeAttrs
      (dream2nix.makeOutputs {source = $sourceTargetDir/src;}).packages
      [\"resolveImpure\"]
    ))
  " > $resolveDatas

  for resolveData in $(jq '.[]' -c -r $resolveDatas); do
    # extract project data so we can determine where the dream-lock.json will be
    name=$(echo "$resolveData" | jq '.name' -c -r)
    relPath=$(echo "$resolveData" | jq '.relPath' -c -r)
    drvPath=$(echo "$resolveData" | jq '.drvPath' -c -r)

    # build the resolve script and run it
    nix build --out-link $TMPDIR/resolve $drvPath
    $TMPDIR/resolve/bin/resolve

    # extract data from dream-lock so we can patch the dream-lock
    dreamLock="$targetDir/$name/$relPath/dream-lock.json"
    defaultPackageName="$(jq '._generic.defaultPackage' -c -r $dreamLock)"
    defaultPackageVersion="$(jq "._generic.packages.\"$defaultPackageName\"" -c -r $dreamLock)"
    sourceInfo="$(jq . -c -r $sourceTargetDir/sourceInfo.json)"

    # patch the dream-lock with our source info so the dream-lock works standalone
    jqQuery=".sources.\"$defaultPackageName\".\"$defaultPackageVersion\" = $sourceInfo"
    jq "$jqQuery" -c -r "$dreamLock" | sponge "$dreamLock"

    echo "resolved $defaultPackageName-$defaultPackageVersion (project $name)"
  done
''
