{
  # dream2nix deps
  callNixWithD2N,
  translate,
  writers,
  coreutils,
  ...
}:
writers.writeBashBin
"shell"
''
  set -e

  source="''${1:?"error: pass a source shortcut"}"
  TMPDIR="$(${coreutils}/bin/mktemp --directory)"

  export translateSkipResolved=1
  export translateSourceInfoPath="$TMPDIR/sourceInfo.json"
  ${translate}/bin/translate "$source" "packages"

  export dream2nixConfig="{packagesDir=\"packages\"; projectRoot=\"$TMPDIR\";}"

  ${callNixWithD2N} shell "
    (dream2nix.realizeProjects {
      source = dream2nix.fetchers.fetchSource {
        source = l.fromJSON (l.readFile \"$translateSourceInfoPath\");
      };
    }).packages
  "
''
