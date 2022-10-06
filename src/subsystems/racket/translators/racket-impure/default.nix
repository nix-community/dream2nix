{
  utils,
  pkgs,
  ...
}: {
  type = "impure";

  # A derivation which outputs a single executable at `$out`.
  # The executable will be called by dream2nix for translation
  # The input format is specified in /specifications/translator-call-example.json.
  # The first arg `$1` will be a json file containing the input parameters
  # like defined in /src/specifications/translator-call-example.json and the
  # additional arguments required according to extraArgs
  #
  # The program is expected to create a file at the location specified
  # by the input parameter `outFile`.
  # The output file must contain the dream lock data encoded as json.
  # See /src/specifications/dream-lock-example.json
  translateBin = let
    inherit
      (pkgs)
      bash
      coreutils
      fetchurl
      jq
      nix
      racket
      runCommandLocal
      ;

    pruned-racket-catalog = let
      src = fetchurl {
        url = "https://github.com/nix-community/pruned-racket-catalog/tarball/9f11e5ea5765c8a732c5e3129ca2b71237ae2bac";
        sha256 = "sha256-/n30lailqSndoqPGWcFquCpQWVQcciMiypXYLhNmFUo=";
      };
    in
      runCommandLocal "pruned-racket-catalog" {} ''
        mkdir $out
        cd $out
        tar --strip-components 1 -xf ${src}
      '';
  in
    utils.writePureShellScript
    [
      bash
      coreutils
      jq
      nix
      racket
    ]
    ''
      # according to the spec, the translator reads the input from a json file
      jsonInput=$1

      # read the json input
      outputFile=$(realpath -m $(jq '.outputFile' -c -r $jsonInput))
      source=$(jq '.source' -c -r $jsonInput)
      relPath=$(jq '.project.relPath' -c -r $jsonInput)
      name=$(jq '.project.name' -c -r $jsonInput)

      export RACKET_OUTPUT_FILE=$outputFile
      export RACKET_SOURCE=$source
      export RACKET_RELPATH=$relPath
      export RACKET_PKG_MAYBE_NAME=$name

      racket -e '(require (file "${./generate-dream-lock.rkt}")) (generate-dream-lock "${pruned-racket-catalog}/pkgs-all")'
    '';

  # If the translator requires additional arguments, specify them here.
  # When users run the CLI, they will be asked to specify these arguments.
  # There are only two types of arguments:
  #   - string argument (type = "argument")
  #   - boolean flag (type = "flag")
  # String arguments contain a default value and examples. Flags do not.
  extraArgs = {};
}
