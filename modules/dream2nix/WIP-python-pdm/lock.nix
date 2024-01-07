{
  config,
  lib,
  ...
}: let
  pdmConfig = config.deps.writeText "pdm-config.toml" ''
    check_update = false
    [python]
    use_venv = false
  '';

  script = config.deps.writeScript "pdm-lock" ''
    #!${config.deps.bash}/bin/bash
    set -Eeuo pipefail

    export PATH="$PATH:${lib.makeBinPath [
      config.deps.coreutils
      config.deps.pdm
      config.deps.yq
    ]}"
    export TMPDIR=$(${config.deps.coreutils}/bin/mktemp -d)
    trap "${config.deps.coreutils}/bin/chmod -R +w '$TMPDIR'; ${config.deps.coreutils}/bin/rm -rf '$TMPDIR'" EXIT

    # vscode likes to set these for whatever reason and it crashes PDM
    unset _PYTHON_SYSCONFIGDATA_NAME _PYTHON_HOST_PLATFORM

    pushd "$(${config.paths.findRoot})/${config.paths.package}"

    echo ${config.deps.python3}/bin/python3 > .pdm-python
    pdm -c ${pdmConfig} lock --refresh

    popd
  '';
in {
  lock.extraScripts = [script];
  deps = {nixpkgs, ...}:
    lib.mapAttrs (_: lib.mkDefault) {
      inherit
        (nixpkgs)
        bash
        coreutils
        pdm
        writeScript
        writeText
        yq
        ;
    };
}
