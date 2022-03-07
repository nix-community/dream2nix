{
  async,
  coreutils,
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
    [
      async
      coreutils
    ]
    ''
      S=$(mktemp)
      async -s=$S server --start -j$(nproc)

      for test in ${toString allTests}; do
        async -s=$S cmd -- $test
      done

      async -s=$S wait
      rm $S
    '';


in
  executeAll
