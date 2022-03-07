{
  runCommand,
  writeScript,
  # dream2nix inputs
  dream2nixWithExternals,
  ...
}: {
  program =
    writeScript "install"
    ''
      target="$1"
      if [[ "$target" == "" ]]; then
        echo "specify target"
        exit 1
      fi

      mkdir -p "$target"
      if [ -n "$(ls -A $target)" ]; then
        echo "target directory not empty"
        exit 1
      fi

      cp -r ${dream2nixWithExternals}/* $target/
      chmod -R +w $target

      echo "Installed dream2nix successfully to '$target'."
      echo "Please check/modify settings in '$target/config.json'"
    '';
}
