{
  lib,
  bash,
  coreutils,
  gawk,
  path, # nixpkgs path
  writeScript,
  writeScriptBin,
  ...
}: let
  /*
  create a script that runs in a `pure` environment, in the sense that:
  - PATH only contains exactly the packages passed via the PATH arg
  - NIX_PATH is set to the path of the current `pkgs`
  - TMPDIR is set up and cleaned up even if the script fails
  - out, if set, is kept as-is
  - all environment variables are unset, except:
  - the ones listed in `keepVars` below
  - ones listed via the KEEP_VARS variable
  - the behavior is similar to `nix-shell --pure`
  */
  writePureShellScript = PATH: script:
    writeScript "script.sh" (mkScript PATH script);

  writePureShellScriptBin = binName: PATH: script:
    writeScriptBin binName (mkScript PATH script);

  mkScript = PATH: script: ''
    #!${bash}/bin/bash
    set -Eeuo pipefail

    export PATH="${lib.makeBinPath PATH}"
    export NIX_PATH=nixpkgs=${path}

    export TMPDIR=$(${coreutils}/bin/mktemp -d)

    trap "${coreutils}/bin/chmod -R +w '$TMPDIR'; ${coreutils}/bin/rm -rf '$TMPDIR'" EXIT

    if [ -z "''${IMPURE:-}" ]; then
      ${cleanEnv}
    fi

    ${script}
  '';

  # list taken from nix source: src/nix-build/nix-build.cc
  keepVars = lib.concatStringsSep " " [
    "HOME"
    "XDG_RUNTIME_DIR"
    "USER"
    "LOGNAME"
    "DISPLAY"
    "WAYLAND_DISPLAY"
    "WAYLAND_SOCKET"
    "PATH"
    "TERM"
    "IN_NIX_SHELL"
    "NIX_SHELL_PRESERVE_PROMPT"
    "TZ"
    "PAGER"
    "NIX_BUILD_SHELL"
    "SHLVL"
    "http_proxy"
    "https_proxy"
    "ftp_proxy"
    "all_proxy"
    "no_proxy"

    # We want to keep out own variables as well
    "out"
    "IMPURE"
    "KEEP_VARS"
    "NIX_PATH"
    "TMPDIR"
  ];

  cleanEnv = ''

    KEEP_VARS="''${KEEP_VARS:-}"

    unsetVars=$(
      ${coreutils}/bin/comm \
        <(${gawk}/bin/awk 'BEGIN{for(v in ENVIRON) print v}' | ${coreutils}/bin/cut -d = -f 1 | ${coreutils}/bin/sort) \
        <(echo "${keepVars} $KEEP_VARS" | ${coreutils}/bin/tr " " "\n" | ${coreutils}/bin/sort) \
        -2 \
        -3
    )

    unset $unsetVars
  '';
in {
  inherit
    writePureShellScript
    writePureShellScriptBin
    ;
}
