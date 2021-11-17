{
  lib,

  # dream2nix
  callPackageDream,
  utils,
  ...
}:
let

  l = lib // builtins;

  allTestFiles =
    l.attrNames
      (l.filterAttrs
        (name: type: type == "regular" && l.hasPrefix "test_" name)
        (l.readDir ./.));

  allTests =
    l.map
      (file: callPackageDream ("${./.}/${file}") {})
      allTestFiles;

  executeAll = utils.writePureShellScript
    []
    ''
      for test in ${toString allTests}; do
        $test
      done
    '';


in
  executeAll
