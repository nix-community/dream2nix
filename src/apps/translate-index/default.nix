{
  apps,
  utils,
  pkgs,
  ...
}: let
  script =
    utils.writePureShellScript
    (with pkgs; [coreutils apps.translate jq python3])
    ''
      jobJson=$1
      job_nr=$2
      time=$(date +%s)
      runtime=$(($time - $start_time))
      average_runtime=$(python3 -c "print($runtime / $job_nr)")
      total_remaining_time=$(python3 -c "print($average_runtime * ($num_jobs - $job_nr))")
      echo "starting job nr. $job_nr; average job runtime: $average_runtime sec; remaining time: $total_remaining_time sec"

      # if job fails, store error in ./translation-errors/$jobId.log
      translate $jobJson $targetDir &> $TMPDIR/log \
        || (
          echo "Failed to translate $1"
          jobId=$(jq '.id' -c -r <(echo "$jobJson"))
          logFile="./translation-errors/$jobId.log"
          mkdir -p $(dirname "$logFile")
          cp $TMPDIR/log "$logFile"
        )
    '';
in
  utils.writePureShellScriptBin
  "translate-index"
  (with pkgs; [coreutils apps.translate jq parallel python3])
  ''
    set -e
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
    for translator in $(jq '.[] | .translator' -c -r $index); do
      bin="$TRANSLATOR_DIR/$translator"
      if [ ! -e "$bin" ]; then
        echo "building executable for translator $translator"
        ${apps.callNixWithD2N} build -o "$bin" "
          dream2nix.translators.$translator.finalTranslateBin
        "
      fi
    done

    rm -rf $targetDir

    export start_time=$(date +%s)
    parallel --halt now,fail=1 -j$JOBS --link -a <(jq '.[]' -c -r $index) -a $TMPDIR/job_numbers ${script}

    runtime=$(($(date +%s) - $start_time))
    echo "FINISHED! Executed $num_jobs jobs in $runtime seconds"

    python3 ${./summarize-stats.py} translation-errors.json
  ''
