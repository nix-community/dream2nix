{
  dlib,
  lib,
}: {
  # A derivation which outputs a single executable at `$out`.
  # The executable will be called by dream2nix for translation
  # The input format is specified in /specifications/translator-call-example.json.
  # The first arg `$1` will be a json file containing the input parameters
  # like defined in /specifications/translator-call-example.json and the
  # additional arguments required according to extraArgs
  #
  # The program is expected to create a file at the location specified
  # by the input parameter `outFile`.
  # The output file must contain the dream lock data encoded as json.
  translateBin = {
    # dream2nix utils
    utils,
    # nixpkgs dependenies
    bash,
    jq,
    writeScriptBin,
    ...
  }:
    utils.writePureShellScript
    [
      bash
      coreutils
      jq
      nix
    ]
    ''
      # accroding to the spec, the translator reads the input from a json file
      jsonInput=$1

      # read the json input
      outputFile=$(${jq}/bin/jq '.outputFile' -c -r $jsonInput)
      source=$(${jq}/bin/jq '.source' -c -r $jsonInput)
      inputFiles=$(${jq}/bin/jq '.inputFiles | .[]' -c -r $jsonInput)

      # TODO:
      # read input files/dirs and produce a json file at $outputFile
      # containing the dream lock similar to /specifications/dream-lock-example.json
    '';

  # This function should return the projects name.
  # The computational complexity of this should be kept as lightweight
  # as possible, as this migth be executed on a large amount of inputs at once.
  projectName = {source}:
    null;

  # This allows the framework to detect if the translator is compatible with the given input
  # to automatically select the right translator.
  compatible = {source}:
  # TODO: insert regex here that matches valid input file names
  # examples:
  #   - ''.*requirements.*\.txt''
  #   - ''.*package-lock\.json''
    dlib.containsMatchingFile
    [
      ''TODO: regex1''
      ''TODO: regex2''
    ]
    source;

  # If the translator requires additional arguments, specify them here.
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
