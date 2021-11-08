{
  lib,
  nodejs,

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

      # arguments specified by user
      noDev,
      nodejs,
      ...
    }@args:
    let

      l = lib // builtins;

      # parse the json / toml etc.
      parsed = ;
  
    in

      utils.simpleTranslate translatorName {
        

        # VALUES
        
        # The raw input data as an attribute set.
        # This will then be processed by `serializePackages` (see below) and
        # transformed into a flat list.
        inputData = ;

        mainPackageName = ;

        mainPackageVersion = ;

        mainPackageDependencies =
          lib.mapAttrsToList
            () # some function
            parsedDependencies;

        # the name of the subsystem
        subsystemName = "nodejs";

        # Extract subsystem specific attributes.
        # The structure of this should be defined in:
        #   ./src/specifications/{subsystem}
        subsystemAttrs = { nodejsVersion = args.nodejs; };


        # FUNCTIONS

        # return a list of package objects of arbitrary structure
        serializePackages = inputData: ;

        # return the name for a package object
        getName = dependencyObject: ;

        # return the version for a package object
        getVersion = dependencyObject: ;

        # get dependencies of a dependency object
        getDependencies = dependencyObject: getDepByNameVer: dependenciesByOriginalID:
          dependencyObject.depsExact;

        # return the soruce type of a package object
        getSourceType = dependencyObject:
          # example
          if utils.identifyGitUrl dependencyObject.resolved then
            "git"
          else
            "http";

        # An attrset of constructor functions.
        # Given a dependency object and a source type, construct the 
        # source definition containing url, hash, etc.
        sourceConstructors = {

          git = dependencyObject:
            {
              url = ;
              rev = ;
            };

          github = dependencyObject:
            {
              owner = ;
              repo = ;
              rev = ;
              hash = ;
            };
          
          gitlab = dependencyObject:
            {
              owner = ;
              repo = ;
              rev = ;
              hash = ;
            };

          http = dependencyObject:
            {
              version = ;
              url = ;
              hash = ;
            };
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
