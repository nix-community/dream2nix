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

      _generic = {
        subsystem = "nodejs";
        producedBy = translatorName;
        mainPackageName = "some_name";
        mainPackageVersion = "some_version";
        sourcesCombinedHash = null;
      };

      # build system specific attributes
      _subsystem = {

        # example
        nodejsVersion = 14;
      };
      
      dependencies = {};

      cyclicDependencies = {};

      sources = ;
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
      # TODO: insert regex here that matches valid input file names
      # examples:
      #   - ''.*requirements.*\.txt''
      #   - ''.*package-lock\.json''
      inputDirectories = lib.filter 
        (utils.containsMatchingFile [ ''TODO: regex1'' ''TODO: regex2'' ])
        args.inputDirectories;
      
      inputFiles = [];
    };


  # If the translator requires additional arguments, specify them here.
  # There are only two types of arguments:
  #   - string argument (type = "argument")
  #   - boolean flag (type = "flag")
  # String arguments contain a default value and examples. Flags do not.
  extraArgs = {

    # Example: boolean option
    # Flags always default to 'false' if not specified by the user
    dev-dependenices = {
      description = "Include dev dependencies";
      type = "flag";
    };

    # Example: string option
    the-answer = {
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
