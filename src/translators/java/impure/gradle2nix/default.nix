{
  dlib,
  lib,
}: {
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
  translateBin = {
    # dream2nix utils
    utils,
    # nixpkgs dependenies
    bash,
    coreutils,
    jq,
    writeScriptBin,
    callPackage,
    ...
  }:
    utils.writePureShellScript
    [
      bash
      coreutils
      jq
    ]
    ''
      # accroding to the spec, the translator reads the input from a json file
      jsonInput=$1

      # read the json input
      outputFile=$(${jq}/bin/jq '.outputFile' -c -r $jsonInput)
      source=$(${jq}/bin/jq '.source' -c -r $jsonInput)
      relPath=$(${jq}/bin/jq '.project.relPath' -c -r $jsonInput)

      tmpDir=$(mktemp -d)
      nix shell github:kranzes/gradle2nix/8921415b908bc847ee01009a1a5ddd40466533b7 -c \
        gradle2nix --project $source --out-dir $tmpDir

      somehow format the json file created by gradle2nix $tmpDir/gradle-env.json > $outputFile

      # TODO:
      # read input files/dirs and produce a json file at $outputFile
      # containing the dream lock similar to /src/specifications/dream-lock-example.json
    '';

  # If the translator requires additional arguments, specify them here.
  # When users run the CLI, they will be asked to specify these arguments.
  # There are only two types of arguments:
  #   - string argument (type = "argument")
  #   - boolean flag (type = "flag")
  # String arguments contain a default value and examples. Flags do not.
  extraArgs = {
    # Example: boolean option
    # Flags always default to 'false' if not specified by the user
    noDev = {
      description = "Exclude dev dependencies";
      type = "flag";
    };

    # Example: string option
    theAnswer = {
      default = "42";
      description = "The Answer to the Ultimate Question of Life";
      examples = [
        "0"
        "1234"
      ];
      type = "argument";
    };
  };
}
