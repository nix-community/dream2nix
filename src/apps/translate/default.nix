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
  nix
  python3
  moreutils
]
''
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
            # skip this project if we don't want to resolve ones that can be resolved on the fly
            if \"$translateSkipResolved\" == \"1\" && resolve.passthru.project ? dreamLock
            then null
            else
              # write a simple bash script for exporting the data we need
              # this is better since we don't need to call jq multiple times
              # to access the data we need
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

  # resolve the packages
  for resolveData in $(jq '.[]' -c -r $resolveDatas); do
    # extract project data so we can determine where the dream-lock.json will be
    eval "$resolveData"

    echo "Resolving:: $name (subsystem: $subsystem) (lock path: $dreamLockPath)"

    # build the resolve script and run it
    nix build --out-link $TMPDIR/resolve $drvPath
    $TMPDIR/resolve/bin/resolve

    # patch the dream-lock with our source info so the dream-lock works standalone
    ${callNixWithD2N} eval --json "
      with dream2nix.utils.dreamLock;
      replaceRootSources {
        dreamLock = l.fromJSON (l.readFile \"$targetDir/$dreamLockPath\");
        newSourceRoot = l.fromJSON (l.readFile \"$sourceInfoPath\");
      }
    " \
      | python3 ${../cli/format-dream-lock.py} \
      | sponge "$dreamLockPath"

    echo "Resolved:: $name (subsystem: $subsystem) (lock path: $dreamLockPath)"
  done
''
