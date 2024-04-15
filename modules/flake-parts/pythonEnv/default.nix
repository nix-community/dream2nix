{self, ...}: {
  perSystem = {
    pkgs,
    lib,
    ...
  }: let
    python = pkgs.python3;
    pythonAttr = "python${lib.versions.major python.version}${lib.versions.minor python.version}";
    pdmConfig = pkgs.writeText "pdm-config.toml" ''
      check_update = false
      [python]
      use_venv = false
    '';
    pythonEnv = pkgs.writeScriptBin "pythonWith" ''
      #!${pkgs.bash}/bin/bash
      set -Eeuo pipefail

      export PATH="$PATH:${lib.makeBinPath [
        pkgs.coreutils
        pkgs.pdm
        pkgs.yq
      ]}"
      export TMPDIR=$(${pkgs.coreutils}/bin/mktemp -d)
      # trap "${pkgs.coreutils}/bin/chmod -R +w '$TMPDIR'; ${pkgs.coreutils}/bin/rm -rf '$TMPDIR'" EXIT
      pushd $TMPDIR >/dev/null

      # vscode likes to set these for whatever reason and it crashes PDM
      unset _PYTHON_SYSCONFIGDATA_NAME _PYTHON_HOST_PLATFORM

      echo ${python}/bin/python > .pdm-python
      cat <<EOF > pyproject.toml
      [project]
      name = "temp"
      version = "0.0.0"
      requires-python = "==${python.version}"
      dependencies = [
      EOF

      for dep in "$@"; do
        echo "  \"$dep\"," >> pyproject.toml
      done

      echo "]" >> pyproject.toml
      pdm -c ${pdmConfig} lock
      popd >/dev/null

      # initialize flake template
      cat ${./flake-template.nix} > $TMPDIR/flake.nix
      sed -i 's\__PYTHON_ATTR__\${pythonAttr}\g' $TMPDIR/flake.nix

      # enter dev-shell
      nix develop $TMPDIR -c $SHELL
    '';
  in {
    packages.__pythonEnv = pythonEnv;
  };
}
