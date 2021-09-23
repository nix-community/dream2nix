{
  pkgs,

  callPackage,
  externalSources,
  location,
  translators,
  ...
}:
{

  # the unified translator cli
  cli = callPackage (import ./cli) {};

  # the contribute cli
  contribute = callPackage (import ./contribute) {};

  # install the framework to a specified location by copying the code
  install = callPackage ({ writeScript, }:
    writeScript
      "install"
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

        cp -r ${location}/* $target/
        mkdir $target/external
        cp -r ${externalSources}/* $target/external/
        chmod -R +w $target

        echo "Installed dream2nix successfully to '$target'."
        echo "Please check/modify settings in '$target/config.json'"
      ''
  ) {};
}
