{
  # dream2nix deps
  utils,
  callNixWithD2N,
  translateSourceShortcut,
  coreutils,
  moreutils,
  nix,
  python3,
  jq,
  ...
}:
utils.writePureShellScriptBin
"translate"
[
  jq
  coreutils
  moreutils
  nix
  python3
]
''
  cd $WORKDIR

  usage="usage:
    $0 SOURCE_SHORTCUT TARGET_DIR"

  if [ "$#" -ne 2 ]; then
    echo "error: wrong number of arguments"
    echo "$usage"
    exit 1
  fi

  source=''${1:?"error: pass a source shortcut"}
  targetDir=''${2:?"error: please pass a target directory"}
  targetDir="$(realpath "$targetDir")"

  sourceInfoPath=''${translateSourceInfoPath:-"$TMPDIR/sourceInfo.json"}
  translateSkipResolved=''${translateSkipResolved:-"0"}

  mkdir -p $targetDir && cd $targetDir

  export dream2nixConfig="{packagesDir=\"./.\"; projectRoot=\"$targetDir\";}"

  # translate the source shortcut
  ${translateSourceShortcut} $source > $sourceInfoPath

  # collect data for the packages we will resolve
  resolveDatas="$TMPDIR/resolveData.json"
  ${callNixWithD2N} eval --json "
    let
      data =
        l.map
        (
          p:
          let
            resolve = p.passthru.resolve or p.resolve;
            mkBashEnv = name: value:
              \"\''${name}=\" + \"'\" + value + \"'\";
          in
            if \"$translateSkipResolved\" == \"1\" && resolve.passthru.project ? dreamLock
            then null
            else
              l.concatStringsSep
              \";\"
              (
                (with resolve.passthru.project; [
                  (mkBashEnv \"name\" name)
                  (mkBashEnv \"dreamLockPath\" dreamLockPath)
                  (mkBashEnv \"subsystem\" subsystem)
                ]) ++ [
                  (mkBashEnv \"drvPath\" resolve.drvPath)
                ]
              )
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

  # extract source info once here so we can use it later
  sourceInfo="$(jq '.' -c -r "$sourceInfoPath")"

  # resolve the packages
  for resolveData in $(jq '.[]' -c -r $resolveDatas); do
    # extract project data so we can determine where the dream-lock.json will be
    eval "$resolveData"

    echo "Resolving:: $name (subsystem: $subsystem) (lock path: $dreamLockPath)"

    # build the resolve script and run it
    nix build --out-link $TMPDIR/resolve $drvPath
    $TMPDIR/resolve/bin/resolve

    # patch the dream-lock with our source info so the dream-lock works standalone
    patchLockQuery="
      .sources
      | to_entries
      | map(.value = (.value | to_entries))
      | map(
        .value =
          (
            .value
            | map(
                if (
                  .value
                  | .type == \"path\"
                    and .rootName == null
                    and .rootVersion == null
                )
                then .value = ($sourceInfo | .dir = .value.relPath)
                else . end
              )
          )
        )
      | map(.value = (.value | from_entries))
      | from_entries
    "
    jq ".sources = ($patchLockQuery)" -c -r "$dreamLockPath" \
      | python3 ${../cli/format-dream-lock.py} \
      | sponge "$dreamLockPath"

    echo "Resolved:: $name (subsystem: $subsystem) (lock path: $dreamLockPath)"
  done
''
