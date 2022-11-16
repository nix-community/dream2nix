{
  lib,
  nodeDeps,
}: let
  # The python script wich is executed in this phase:
  #   - ensures that the package is compatible to the current system
  #   - ensures the main version in package.json matches the expected
  #   - pins dependency versions in package.json
  #     (some npm commands might otherwise trigger networking)
  #   - creates symlinks for executables declared in package.json
  # Apart from that:
  #   - Any usage of 'link:' in package.json is replaced with 'file:'
  #   - If package-lock.json exists, it is deleted, as it might conflict
  #     with the parent package-lock.json.
  d2nPatch = ''
    # delete package-lock.json as it can lead to conflicts
    rm -f package-lock.json

    # repair 'link:' -> 'file:'
    mv $nodeModules/$packageName/package.json $nodeModules/$packageName/package.json.old
    cat $nodeModules/$packageName/package.json.old | sed 's!link:!file\:!g' > $nodeModules/$packageName/package.json
    rm $nodeModules/$packageName/package.json.old

    # run python script (see comment above):
    cp package.json package.json.bak
    python $fixPackage \
    || \
    # exit code 3 -> the package is incompatible to the current platform
    #  -> Let the build succeed, but don't create lib/node_modules
    if [ "$?" == "3" ]; then
      mkdir -p $out
      echo "Not compatible with system $system" > $out/error
      exit 0
    else
      exit 1
    fi
  '';
in
  ''
    runHook preConfigure
  ''
  + d2nPatch
  + ''
    # symlink sub dependencies as well as this imitates npm better
    python $installDeps

    echo "Symlinking transitive executables to $nodeModules/.bin"
    for dep in ${lib.toString nodeDeps}; do
      binDir=$dep/lib/node_modules/.bin
      if [ -e $binDir ]; then
        for bin in $(ls $binDir/); do\
          if [ ! -e $nodeModules/.bin ]; then
            mkdir -p $nodeModules/.bin
          fi

          # symlink might have been already created by install-deps.py
          # if installMethod=copy was selected
          if [ ! -L $nodeModules/.bin/$bin ]; then
            ln -s $binDir/$bin $nodeModules/.bin/$bin
          else
            echo "won't overwrite existing symlink $nodeModules/.bin/$bin. current target: $(readlink $nodeModules/.bin/$bin)"
          fi
        done
      fi
    done

    # add bin path entries collected by python script
    export PATH="$PATH:$nodeModules/.bin"

    # add dependencies to NODE_PATH
    export NODE_PATH="$NODE_PATH:$nodeModules/$packageName/node_modules"

    export HOME=$TMPDIR

    runHook postConfigure
  ''
