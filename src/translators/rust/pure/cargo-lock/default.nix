{
  dlib,
  lib,
}: let
  l = lib // builtins;
in {
  translate = {
    externals,
    translatorName,
    utils,
    ...
  }: {
    source,
    packageName,
    ...
  } @ args: let
    inputDir = source;

    recurseFiles = path:
      l.flatten (
        l.mapAttrsToList
        (n: v:
          if v == "directory"
          then recurseFiles "${path}/${n}"
          else "${path}/${n}")
        (l.readDir path)
      );

    # Find all Cargo.toml files and parse them
    allFiles = l.flatten (l.map recurseFiles [inputDir]);
    cargoTomlPaths = l.filter (path: l.baseNameOf path == "Cargo.toml") allFiles;
    cargoTomls =
      l.map
      (path: {
        inherit path;
        value = l.fromTOML (l.readFile path);
      })
      cargoTomlPaths;

    # Filter cargo-tomls to for files that actually contain packages
    cargoPackages =
      l.filter
      (toml: l.hasAttrByPath ["package" "name"] toml.value)
      cargoTomls;

    packageName =
      if args.packageName == "{automatic}"
      then let
        # Small function to check if a given package path has a package
        # that has binaries
        hasBinaries = toml:
          l.hasAttr "bin" toml.value
          || l.pathExists "${l.dirOf toml.path}/src/main.rs"
          || l.pathExists "${l.dirOf toml.path}/src/bin";

        # Try to find a package with a binary
        pkg = l.findFirst hasBinaries (l.elemAt cargoPackages 0) cargoPackages;
      in
        pkg.value.package.name
      else args.packageName;

    # Find the Cargo.toml matching the package name
    checkForPackageName = cargoToml: (cargoToml.value.package.name or null) == packageName;
    packageToml =
      l.findFirst
      checkForPackageName
      (throw "no Cargo.toml found with the package name passed: ${packageName}")
      cargoTomls;

    # Parse Cargo.lock and extract dependencies
    parsedLock = l.fromTOML (l.readFile "${inputDir}/Cargo.lock");
    parsedDeps = parsedLock.package;
    # This parses a "package-name version" entry in the "dependencies"
    # field of a dependency in Cargo.lock
    makeDepNameVersion = entry: let
      parsed = l.splitString " " entry;
      name = l.head parsed;
      maybeVersion =
        if l.length parsed > 1
        then l.last parsed
        else null;
    in {
      inherit name;
      version =
        # If there is no version, search through the lockfile to
        # find the dependency's version
        if maybeVersion != null
        then maybeVersion
        else
          (
            l.findFirst
            (dep: dep.name == name)
            (throw "no dependency found with name ${name} in Cargo.lock")
            parsedDeps
          )
          .version;
    };

    package = rec {
      toml = packageToml.value;
      tomlPath = packageToml.path;

      name = toml.package.name;
      version = toml.package.version or (l.warn "no version found in Cargo.toml for ${name}, defaulting to unknown" "unknown");
    };

    # Parses a git source, taken straight from nixpkgs.
    parseGitSource = src: let
      parts = builtins.match ''git\+([^?]+)(\?(rev|tag|branch)=(.*))?#(.*)'' src;
      type = builtins.elemAt parts 2; # rev, tag or branch
      value = builtins.elemAt parts 3;
    in
      if parts == null
      then null
      else
        {
          url = builtins.elemAt parts 0;
          sha = builtins.elemAt parts 4;
        }
        // lib.optionalAttrs (type != null) {inherit type value;};

    # Extracts a source type from a dependency.
    getSourceTypeFrom = dependencyObject: let
      checkType = type: l.hasPrefix "${type}+" dependencyObject.source;
    in
      if !(l.hasAttr "source" dependencyObject)
      then "path"
      else if checkType "git"
      then "git"
      else if checkType "registry"
      then
        if dependencyObject.source == "registry+https://github.com/rust-lang/crates.io-index"
        then "crates-io"
        else throw "registries other than crates.io are not supported yet"
      else throw "unknown or unsupported source type: ${dependencyObject.source}";
  in
    utils.simpleTranslate
    ({
      getDepByNameVer,
      dependenciesByOriginalID,
      ...
    }: rec {
      # VALUES

      inherit translatorName;

      # The raw input data as an attribute set.
      # This will then be processed by `serializePackages` (see below) and
      # transformed into a flat list.
      inputData = parsedDeps;

      defaultPackage = package.name;

      packages =
        (l.listToAttrs
          (l.map
            (toml:
              l.nameValuePair
              toml.value.package.name
              toml.value.package.version)
            cargoPackages))
        // {"${defaultPackage}" = package.version;};

      mainPackageDependencies = let
        mainPackage =
          l.findFirst
          (dep: dep.name == package.name)
          (throw "could not find main package in Cargo.lock")
          parsedDeps;
      in
        l.map makeDepNameVersion (mainPackage.dependencies or []);

      # the name of the subsystem
      subsystemName = "rust";

      # Extract subsystem specific attributes.
      # The structure of this should be defined in:
      #   ./src/specifications/{subsystem}
      subsystemAttrs = rec {
        gitSources = let
          gitDeps = l.filter (dep: (getSourceTypeFrom dep) == "git") parsedDeps;
        in
          l.unique (l.map (dep: parseGitSource dep.source) gitDeps);
      };

      # FUNCTIONS

      # return a list of package objects of arbitrary structure
      serializePackages = inputData: inputData;

      # return the name for a package object
      getName = dependencyObject: dependencyObject.name;

      # return the version for a package object
      getVersion = dependencyObject: dependencyObject.version;

      # get dependencies of a dependency object
      getDependencies = dependencyObject:
        l.map makeDepNameVersion (dependencyObject.dependencies or []);

      # return the source type of a package object
      getSourceType = getSourceTypeFrom;

      # An attrset of constructor functions.
      # Given a dependency object and a source type, construct the
      # source definition containing url, hash, etc.
      sourceConstructors = {
        path = dependencyObject: let
          toml = (
            l.findFirst
            (toml: toml.value.package.name == dependencyObject.name)
            (throw "could not find crate ${dependencyObject.name}")
            cargoPackages
          );
          relDir = lib.removePrefix "${inputDir}/" (l.dirOf toml.path);
        in {
          path = relDir;
          rootName = package.name;
          rootVersion = package.version;
        };

        git = dependencyObject: let
          parsed = parseGitSource dependencyObject.source;
        in {
          url = parsed.url;
          rev = parsed.sha;
        };

        crates-io = dependencyObject: {
          hash = dependencyObject.checksum;
        };
      };
    });

  projectName = {source}: let
    cargoToml = "${source}/Cargo.toml";
  in
    if l.pathExists cargoToml
    then (l.fromTOML (l.readFile cargoToml)).package.name or null
    else null;

  # This allows the framework to detect if the translator is compatible with the given input
  # to automatically select the right translator.
  compatible = {source}:
    dlib.containsMatchingFile [''.*Cargo\.lock''] source;

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
