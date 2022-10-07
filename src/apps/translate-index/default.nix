{
  callNixWithD2N,
  utils,
  translate,
  coreutils,
  jq,
  parallel,
  python3,
  writeScript,
  ...
}: let
  script =
    utils.writePureShellScript
    [coreutils translate jq python3]
    ''
      job_nr=$2
      time=$(date +%s)
      runtime=$(($time - $start_time))
      average_runtime=$(python3 -c "print($runtime / $job_nr)")
      total_remaining_time=$(python3 -c "print($average_runtime * ($num_jobs - $job_nr))")
      echo "starting job nr. $job_nr; average job runtime: $average_runtime sec; remaining time: $total_remaining_time sec"
      translate $1 $targetDir || echo "Failed to translate $1"
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

    export num_jobs=$(jq 'length' -c -r $index)
    seq $num_jobs > $TMPDIR/job_numbers

    JOBS=''${JOBS:-$(nproc)}

    # build translator executables
    export TRANSLATOR_DIR=$TMPDIR/translators
    for translator in $(jq '.[] | .translator' -c -r libraries-io/index.json); do
      bin="$TRANSLATOR_DIR/$translator"
      if [ ! -e "$bin" ]; then
        echo "building executable for translator $translator"
        ${callNixWithD2N} build -o "$bin" "
          dream2nix.framework.translators.$translator.translateBinFinal
        "
      fi
    done

    export start_time=$(date +%s)
    parallel --halt now,fail=1 -j$JOBS --link -a <(jq '.[]' -c -r $index) -a $TMPDIR/job_numbers ${script}

    runtime=$(($(date +%s) - $start_time))
    echo "FINISHED! Executed $num_jobs jobs in $runtime seconds"
  ''
