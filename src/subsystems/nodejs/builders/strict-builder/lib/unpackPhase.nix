{}:
# TODO: upstream fix to nixpkgs
# example which requires this:
# https://registry.npmjs.org/react-window-infinite-loader/-/react-window-infinite-loader-1.0.7.tgz
''
  runHook preUnpack

  export sourceRoot="$name"

  # sometimes tarballs do not end with .tar.??
  unpackFallback(){
    local fn="$1"
    tar xf "$fn"
  }

  unpackCmdHooks+=(unpackFallback)

  unpackFile $src

  # Make the base dir in which the target dependency resides in first
  mkdir -p "$(dirname "$sourceRoot")"

  # install source
  if [ -f "$src" ]
  then
      # Figure out what directory has been unpacked
      packageDir="$(find . -maxdepth 1 -type d | tail -1)"

      # Restore write permissions
      find "$packageDir" -type d -exec chmod u+x {} \;
      chmod -R u+w -- "$packageDir"

      # Move the extracted tarball into the output folder

      mv -- "$packageDir" "$sourceRoot"
  elif [ -d "$src" ]
  then
      strippedName="$(stripHash $src)"

      # Restore write permissions
      chmod -R u+w -- "$strippedName"

      # Move the extracted directory into the output folder
      mv -- "$strippedName" "$sourceRoot"
  fi

  runHook postUnpack
''
