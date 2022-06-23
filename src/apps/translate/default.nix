{
  # dream2nix deps
  utils,
  callNixWithD2N,
  fetchSourceShortcut,
  coreutils,
  ...
}:
utils.writePureShellScriptBin
"translate"
[
  coreutils
  fetchSourceShortcut
  callNixWithD2N
]
''
  source=''${1:?"error: pass a source shortcut"}
  targetDir=''${2:-"dream2nix-packages"}

  cd $WORKDIR

  mkdir -p $targetDir

  export dream2nixConfig="{packagesDir=\"$targetDir\"; projectRoot=./.;}"

  fetchSourceShortcut $source

  callNixWithD2N build --out-link "$TMPDIR/resolve" "
    b.map
    (p: p.passthru.resolve or p.resolve)
    (b.attrValues (b.removeAttrs
      (dream2nix.makeOutputs {source = ./src;}).packages
      [\"resolveImpure\"]
    ))
  "

  shopt -s nullglob
  for resolve in $TMPDIR/resolve*; do
    $resolve/bin/resolve
  done
  shopt -u nullglob
''
