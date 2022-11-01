{
  dlib,
  lib,
  utils,
  pkgs,
  translators,
  dream2nixWithExternals,
  ...
}: let
  l = lib // builtins;
in {
  type = "impure";

  # disable this as we don't have a builder yet
  # disabled = true;

  discoverProject = tree:
  # Returns true if given directory contains the dist-newstyle/cache/plan.json
    l.pathExists "${tree.fullPath}/go.mod";

  # the input format is specified in /specifications/translator-call-example.json
  # this script receives a json file including the input paths and specialArgs
  translateBin =
    utils.writePureShellScript
    (with pkgs; [
      bash
      coreutils
      jq
      nix
    ])
    ''
      # accroding to the spec, the translator reads the input from a json file
      jsonInput=$1

      # read the json input
      export outputFile=$(realpath -m $(jq '.outputFile' -c -r $jsonInput))
      source=$(jq '.source' -c -r $jsonInput)

      pushd $TMPDIR
      cp -r $source/* .
      chmod -R +w .
      # This should be in sync with gomod2nix version in flake.lock
      nix run github:tweag/gomod2nix/67f22dd738d092c6ba88e420350ada0ed4992ae8

      mkdir -p $(dirname $outputFile)
      nix eval --show-trace --impure --raw --expr "import ${./translate.nix} { \
        dream2nixWithExternals = ${dream2nixWithExternals}; \
      } ./." > $outputFile
    '';

  # If the translator requires additional arguments, specify them here.
  # There are only two types of arguments:
  #   - string argument (type = "argument")
  #   - boolean flag (type = "flag")
  # String arguments contain a default value and examples. Flags do not.
  extraArgs = {};
}
