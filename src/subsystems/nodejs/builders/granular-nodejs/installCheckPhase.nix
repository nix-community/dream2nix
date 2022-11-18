{}: ''
  # Declare an array of string with type
  local pathList="$out/lib/node_modules/.bin/ $out/bin"
  local checkExecExcludes=$installCheckExcludes

  # check if a "./bin" or "node_modules/.bin/" folder exists
  for dir in $pathList; do
    if [ -d "$out" ]
    then
      # $dir is a directory. checking all binaries inside it.
      for binaryLink in "$out"/lib/node_modules/.bin/*
      do
        # The binary must exist
        # realpath follows symlinks recursively the last node MUST exist
        # echo testing binary: $binaryLink

        if [ ! -f $binaryLink ]
        then
          echo binary: $binaryLink is not a file >&2
          exit 1
        elif [ ! -x $(realpath $binaryLink) ]
        then
          echo binary $binaryLink of $packageName is not executable >&2
          exit 1
        else
          # file is an exectuable -> run with `$filename --version`
          if [[ $checkExecExcludes =~ (^|[[:space:]])$(basename $binaryLink)($|[[:space:]]) ]] ; then
            echo "$(basename $binaryLink)" is excluded. Not testing its excution
          else

            jq '.bin' : string | object
            echo executing: $binaryLink --version
            eval $binaryLink --help 2>&1 || EXIT_CODE=$?
            numExitCode=$(($EXIT_CODE + 0))
            if [[ $numExitCode -ne 0 ]];
            then
              echo testCmd: $binaryLink returned with non-zero exit code: $numExitCode
              exit $(($EXIT_CODE))
            fi
          fi

        fi
      done
    fi
  done
''
