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

      ...
    }@args:
    let
      l = lib // builtins;
      
      recurseFiles = path:
        l.flatten (
          l.mapAttrsToList
          (n: v: if v == "directory" then recurseFiles "${path}/${n}" else "${path}/${n}")
          (l.readDir path)
        );

      # Find all Cargo.toml files and parse them
      allFiles = l.flatten (l.map recurseFiles inputDirectories);
      cargoTomlPaths = l.filter (path: l.baseNameOf path == "Cargo.toml") allFiles;
      cargoTomls = l.map (path: { inherit path; value = l.fromTOML (l.readFile path); }) cargoTomlPaths;

      packageName =
        if args.packageName == "{automatic}"
        then
          let
            # Filter cargo-tomls to for files that actually contain packages
            pkgs =
              l.filter
              (toml: l.hasAttrByPath [ "package" "name" ] toml.value)
              cargoTomls;

            # Small function to check if a given package path has a package
            # that has binaries
            hasBinaries = path:
              l.pathExists "${path}/src/main.rs"
                || l.pathExists "${path}/src/bin";

            # Try to find a package with a binary
            pkg =
              l.findFirst
              (toml: hasBinaries (l.dirOf toml.path))
              (l.elemAt pkgs 0)
              pkgs;

          in pkg.value.package.name
        else args.packageName;

      # Find the Cargo.toml matching the package name
      checkForPackageName = cargoToml: (cargoToml.value.package.name or null) == packageName;
      packageToml = l.findFirst checkForPackageName (throw "no Cargo.toml found with the package name passed: ${packageName}") cargoTomls;

      # Find the input directory that will contain the Cargo.lock and include our package's Cargo.toml file
      inputDir =
        l.findFirst
        (path: l.hasPrefix path packageToml.path)
        (throw "no input directory found for package")
        inputDirectories;

      # Parse Cargo.lock and extract dependencies
      parsedLock = l.fromTOML (l.readFile "${inputDir}/Cargo.lock");
      parsedDeps = parsedLock.package;
      # This parses a "package-name version" entry in the "dependencies"
      # field of a dependency in Cargo.lock
      makeDepNameVersion = entry:
        let
          parsed = l.splitString " " entry;
          name = l.head parsed;
          maybeVersion = if l.length parsed > 1 then l.last parsed else null;
        in
        {
          inherit name;
          version =
            # If there is no version, search through the lockfile to
            # find the dependency's version
            if maybeVersion != null
            then maybeVersion
            else (
                   l.findFirst
                   (dep: dep.name == name)
                   (throw "no dependency found with name ${name} in Cargo.lock")
                   parsedDeps
                 ).version;
        };
      
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
          let
            mainPackage =
              l.findFirst
              (dep: dep.name == package.name)
              (throw "could not find main package in Cargo.lock")
              parsedDeps;
          in
          l.map makeDepNameVersion (mainPackage.dependencies or [ ]);

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
        serializePackages = inputData: inputData;

        # return the name for a package object
        getName = dependencyObject: dependencyObject.name;

        # return the version for a package object
        getVersion = dependencyObject: dependencyObject.version;

        # get dependencies of a dependency object
        getDependencies = dependencyObject: getDepByNameVer: dependenciesByOriginalID:
          l.map makeDepNameVersion (dependencyObject.dependencies or [ ]);

        # return the source type of a package object
        getSourceType = dependencyObject:
          let checkType = type: l.hasPrefix "${type}+" dependencyObject.source; in
          if !(l.hasAttr "source" dependencyObject)
          then "path"
          else if checkType "git" then
            "git"
          else if checkType "registry" then
            if dependencyObject.source == "registry+https://github.com/rust-lang/crates.io-index"
            then "crates-io"
            else throw "registries other than crates.io are not supported yet"
          else
            throw "unknown or unsupported source type: ${dependencyObject.source}";

        # An attrset of constructor functions.
        # Given a dependency object and a source type, construct the 
        # source definition containing url, hash, etc.
        sourceConstructors = {
          path = dependencyObject:
            let
              findCratePath = name:
                l.dirOf (
                  l.findFirst
                  (toml: toml.value.package.name == name)
                  (throw "could not find crate ${name}")
                  cargoTomls
                ).path;
            in
            {
              path = findCratePath dependencyObject.name;
            };

          git = dependencyObject:
            let
              source = dependencyObject.source;

              extractRevision = source: l.last (l.splitString "#" source);
              extractRepoUrl = source:
                let
                  splitted = l.head (l.splitString "?" source);
                  split = l.substring 4 (l.stringLength splitted) splitted;
                in l.head (l.splitString "#" split);
            in
            {
              url = extractRepoUrl source;
              rev = extractRevision source;
            };
            
          crates-io = dependencyObject:
            {
              pname = dependencyObject.name;
              version = dependencyObject.version;
              hash = dependencyObject.checksum;
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
      default = "{automatic}";
      examples = ["rand"];
      type = "argument";
    };
  };
}
