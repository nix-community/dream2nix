{
  utils,
  translate,
  coreutils,
  jq,
  parallel,
  writeScript,
  ...
}: let
  script = writeScript "run-translate" ''
    ${translate}/bin/translate $1 $targetDir || echo "Failed to translate $1"
  '';
in
  utils.writePureShellScriptBin
  "translate-index"
  [coreutils translate jq parallel]
  ''
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

    export targetDir

    parallel --halt now,fail=1 -j$(nproc) --delay 1 -a <(jq '.[]' -c -r $index) ${script}

  ''
