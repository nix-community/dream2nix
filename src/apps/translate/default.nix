{
  # dream2nix deps
  apps,
  utils,
  pkgs,
  ...
}:
utils.writePureShellScriptBin
"translate"
(with pkgs; [
  jq
  coreutils
  nix
  python3
  moreutils
])
''
  usage="usage:
    $0 PROJECT_JSON TARGET_DIR"

  if [ "$#" -ne 2 ]; then
    echo "error: wrong number of arguments"
    echo "$usage"
    exit 1
  fi

  projectJson=''${1:?"error: pass projects spec as json string"}
  targetDir=''${2:?"error: please pass a target directory"}
  targetDir="$(realpath "$targetDir")"
  translator=$(jq '.translator' -c -r <(echo $projectJson))
  name=$(jq '.name' -c -r <(echo $projectJson))
  id=$(jq '.id' -c -r <(echo $projectJson))
  if [ "$id" == "null" ]; then
    echo "error: 'id' field not specified for project $name"
    exit 1
  fi
  dreamLockPath="$targetDir/$id/dream-lock.json"

  mkdir -p $targetDir && cd $targetDir

  echo -e "\nTranslating:: $name (translator: $translator) (lock path: $dreamLockPath)"

  # allow pre-built translator executables to avoid the `nix build` on each run
  if [ -n "''${TRANSLATOR_DIR:-""}" ]; then
    translateBin="$TRANSLATOR_DIR/$translator"
  else
    translateBin=$(${apps.callNixWithD2N} build --print-out-paths --no-link "
      dream2nix.framework.translators.$translator.finalTranslateBin
    ")
  fi

  echo "
    {
      \"project\": $projectJson,
      \"outputFile\": \"$dreamLockPath\"
    }
  " > $TMPDIR/args.json

  $translateBin $TMPDIR/args.json

  cat $dreamLockPath \
    | python3 ${utils.scripts.formatDreamLock} \
    | sponge $dreamLockPath

  ${pkgs.python3.pkgs.jsonschema}/bin/jsonschema \
    --instance $dreamLockPath \
    --output pretty \
    --base-uri file:${../../specifications}/ \
    ${../../specifications}/dream-lock-schema.json

  echo -e "\nFinished:: $name (translator: $translator) (lock path: $dreamLockPath)"
''
