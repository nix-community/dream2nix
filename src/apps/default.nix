{
  pkgs,
  location,
}:
let
  callPackage = pkgs.callPackage;
in
{
  # translate cli
  translate = callPackage ({ writeScript, }:
    writeScript
      "translate"
      ''${import ../translators { inherit pkgs; }}/bin/cli "$@"''
  ) {};

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
        chmod -R +w $target
      ''
  ) {};
}
