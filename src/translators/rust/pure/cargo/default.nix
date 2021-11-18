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

      # arguments specified by user
      # TODO: if packageName is not specified, try to find package to build automatically
      packageName,
      ...
    }@args:
    let
      l = lib // builtins;
      
      # TODO: recurse thru all filtered directories and flatten all files
      allFiles = throw "TODO";
      
      # Find all Cargo.toml files and parse them
      cargoTomlPaths = l.filter (path: l.baseNameOf path == "Cargo.toml") allFiles;
      cargoTomls = l.map (path: { inherit path; value = l.fromTOML (l.readFile path); }) cargoTomlPaths;
  
      # Find the Cargo.toml matching the package name
      checkForPackageName = cargoToml: (cargoToml.value.package.name or null) == packageName;
      packageToml = l.findFirst checkForPackageName (throw "no Cargo.toml found with the package name passed") cargoTomls;
  
      # Find the input directory that will contain the Cargo.lock and include our package's Cargo.toml file
      inputDir = l.findFirst (path: l.hasPrefix path packageToml.path) inputDirectories;

      # Parse Cargo.lock and extract dependencies
      parsedLock = l.fromTOML (l.readFile "${inputDir}/Cargo.lock");
      parsedDeps = parsedLock.package;
      
      package = rec {
        toml = packageToml.value;
        tomlPath = packageToml.path;
    
        name = toml.package.name;
        version = toml.package.version or (l.warn "no version found in Cargo.toml for ${name}, defaulting to unknown" "unknown");
      };
    in

      utils.simpleTranslate translatorName {
        # VALUES
        
        # The raw input data as an attribute set.
        # This will then be processed by `serializePackages` (see below) and
        # transformed into a flat list.
        inputData = parsedDeps;
    
        mainPackageName = package.name;

        mainPackageVersion = package.version;

        mainPackageDependencies =
          lib.mapAttrsToList
            (a) # some function
            parsedDependencies;

        # the name of the subsystem
        subsystemName = "rust";

        # Extract subsystem specific attributes.
        # The structure of this should be defined in:
        #   ./src/specifications/{subsystem}
        #
        # TODO: do we pass features to enable / cargo profile to use here?
        subsystemAttrs = { };

        # FUNCTIONS

        # return a list of package objects of arbitrary structure
        serializePackages = inputData: throw "TODO";

        # return the name for a package object
        getName = dependencyObject: throw "TODO";

        # return the version for a package object
        getVersion = dependencyObject: throw "TODO";

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
              url = throw "TODO";
              rev = throw "TODO";
              ref = throw "TODO";
            };
            
          crates-io = dependencyObject: throw "TODO";
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
      inputDirectories = lib.filter 
        (utils.containsMatchingFile [ ''.*Cargo\.lock'' ])
        args.inputDirectories;
      
      inputFiles = [ ];
    };


  # If the translator requires additional arguments, specify them here.
  # When users run the CLI, they will be asked to specify these arguments.
  # There are only two types of arguments:
  #   - string argument (type = "argument")
  #   - boolean flag (type = "flag")
  # String arguments contain a default value and examples. Flags do not.
  extraArgs = {
    packageName = {
      description = "name of the package you want to build";
      type = "argument";
    };
  };
}
