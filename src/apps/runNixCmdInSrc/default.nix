{
  # dream2nix deps
  writeFlakeD2N,
  callNixWithD2N,
  translate,
  writers,
  coreutils,
  nix,
  ...
}:
writers.writeBashBin
"runNixCmdInSrc"
''
  set -e

  usage="usage:
    $0 SOURCE_SHORTCUT [ARGS]
    ARGS will be passed to Nix.
  example:
    $0 github:ripgrep/13.0.0 shell .#ripgrep"

  if [ "$#" -lt 1 ]; then
    echo "error: wrong number of arguments passed"
    echo "$usage"
    exit 1
  fi

  source="''${1:?"error: pass a source shortcut"}"

  TMPDIR="$(${coreutils}/bin/mktemp --directory)"
  SRC="$(${coreutils}/bin/mktemp --directory)"

  # translate any impure packages
  export translateSkipResolved=1
  export translateSourceInfoPath="$SRC/sourceInfo.json"
  ${translate}/bin/translate "$source" "$TMPDIR/packages"

  # write flake.nix file
  export dream2nixConfig="{packagesDir=\"./packages\"; projectRoot=./.;}"
  export flakeSrcInfoPath="$translateSourceInfoPath"
  ${writeFlakeD2N} "$TMPDIR/flake.nix"

  # process arguments to pass to Nix
  args=()
  for arg in ''${@:2:$#}; do
    args+=("''${arg//\.#/$TMPDIR#}")
  done

  # calculate actual command offset so we can pass --impure
  # to the correct command
  argOffset=1
  if [ "''${args[0]}" == "flake" ]; then
    argOffset=2
  fi

  cmdArgs=(''${args[@]::$argOffset})
  remArgs=(''${args[@]:$argOffset})
  if [[ "''${remArgs[@]}" == "" ]]; then
    remArgs+=("$TMPDIR")
  fi

  # enable IFD explicitly so 'flake show' works
  ${nix}/bin/nix --option allow-import-from-derivation true \
    ''${cmdArgs[@]} --impure ''${remArgs[@]}

  ${coreutils}/bin/rm -rf {$TMPDIR,$SRC}
''
