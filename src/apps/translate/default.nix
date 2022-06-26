{
  # dream2nix deps
  utils,
  callNixWithD2N,
  translateSourceShortcut,
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
  nix
  jq
  python3
]
''
  cd $WORKDIR

  source=''${1:?"error: pass a source shortcut"}
  targetDir=''${2:?"error: please pass a target directory"}
  targetDir="$(realpath "$targetDir")"
  sourceInfoPath=''${translateSourceInfoPath:-"$TMPDIR/sourceInfo.json"}
  translateSkipResolved=''${translateSkipResolved:-"0"}

  mkdir -p $targetDir && cd $targetDir

  export dream2nixConfig="{packagesDir=\"./.\"; projectRoot=\"$targetDir\";}"

  ${translateSourceShortcut} $source > $sourceInfoPath

  resolveDatas="$TMPDIR/resolveData.json"
  ${callNixWithD2N} eval --json "
    let
      data =
        l.map
        (
          p:
          let
            resolve = p.passthru.resolve or p.resolve;
          in
            if \"$translateSkipResolved\" == \"1\" && resolve.passthru.project ? dreamLock
            then null
            else {
              inherit (resolve.passthru.project)
                name
                dreamLockPath
                subsystem
                ;
              drvPath = resolve.drvPath;
            }
        )
        (
          l.attrValues
          (
            l.removeAttrs
            (dream2nix.makeOutputs {
              source = dream2nix.fetchers.fetchSource {
                source =
                  l.fromJSON (l.readFile \"$sourceInfoPath\");
              };
            }).packages
            [\"resolveImpure\"]
          )
        );
    in
      l.unique (l.filter (i: i != null) data)
  " > $resolveDatas

  for resolveData in $(jq '.[]' -c -r $resolveDatas); do
    # extract project data so we can determine where the dream-lock.json will be
    name=$(echo "$resolveData" | jq '.name' -c -r)
    subsystem=$(echo "$resolveData" | jq '.subsystem' -c -r)
    dreamLockPath="$targetDir/$(echo "$resolveData" | jq '.dreamLockPath' -c -r)"
    drvPath=$(echo "$resolveData" | jq '.drvPath' -c -r)

    echo "Resolving:: $name (subsystem: $subsystem) (lock path: $dreamLockPath)"

    # build the resolve script and run it
    nix build --out-link $TMPDIR/resolve $drvPath
    $TMPDIR/resolve/bin/resolve

    # patch the dream-lock with our source info so the dream-lock works standalone
    sourceInfo="$(jq . -c -r $sourceInfoPath)"
    jqQuery="._generic.sourceRoot = $sourceInfo"
    jq "$jqQuery" -c -r "$dreamLockPath" \
      | python3 ${../cli/format-dream-lock.py} \
      | sponge "$dreamLockPath"

    echo "Resolved:: $name (subsystem: $subsystem) (lock path: $dreamLockPath)"
  done
''
