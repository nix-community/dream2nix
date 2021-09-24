{
  lib,

  externals,
  translatorName,
  utils,
  ...
}:

{
  translate =
    {
      inputDirectories,
      inputFiles,

      dev,
      ...
    }:
    let
      # TODO: parse input files
    in
    # TODO: produce dream lock like in /specifications/dream-lock-example.json
    rec {
      sources = ;

      generic = {
        buildSystem = "nodejs";
        producedBy = translatorName;
        mainPackage = parsed.name;
        dependencyGraph = ;
        sourcesCombinedHash = null;
      };

      # build system specific attributes
      buildSystem = {

        # example
        nodejsVersion = 14;
      };
    };


  # From a given list of paths, this function returns all paths which can be processed by this translator.
  # This allows the framework to detect if the translator is compatible with the given inputs
  # to automatically select the right translator.
  compatiblePaths =
    {
      inputDirectories,
      inputFiles,
    }@args:
    {
      inputDirectories = [];
      # TODO: insert regex here that matches valid input file names
      # examples:
      #   - ".*(requirements).*\\.txt"
      #   - ".*(package-lock\\.json)"
      inputFiles = lib.filter (f: builtins.match "# TODO: your regex" f != null) args.inputFiles;
    };


  # If the translator requires additional arguments, specify them here.
  # There are only two types of arguments:
  #   - string argument (type = "argument")
  #   - boolean flag (type = "flag")
  # String arguments contain a default value and examples. Flags do not.
  specialArgs = {

    # Example: string option
    # This will be exposed by the translate CLI command as --arg_the-answer
    the-answer = {
      default = "42";
      description = "The Answer to the Ultimate Question of Life";
      examples = [
        "0"
        "1234"
      ];
      type = "argument";
    };

    # Example: boolean option
    # This will be exposed by the translate CLI command as --flag_example-flag
    # The default value of boolean flags is always false
    flat-earth = {
      description = "Is the earth flat";
      type = "flag";
    };

  };
}
