{
  lib,
  nodeDeps,
}: ''
  runHook preConfigure

  # symlink sub dependencies as well as this imitates npm better
  python $installDeps

  echo "Symlinking transitive executables to $nodeModules/.bin"
  for dep in ${toString nodeDeps}; do
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
