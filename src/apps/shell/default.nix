{
  # dream2nix deps
  utils,
  callNixWithD2N,
  translate,
  ...
}:
utils.writePureShellScriptBin
"shell"
[translate callNixWithD2N]
''
  source="''${1:?"error: pass a source shortcut"}"

  translate "$source" "packages"

  export dream2nixConfig="{packagesDir=\"packages\"; projectRoot=./.;}"

  callNixWithD2N shell \
    "(dream2nix.realizeProjects {source = ./src;}).packages"
''
