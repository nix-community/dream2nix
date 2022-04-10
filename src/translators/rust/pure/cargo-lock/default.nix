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
    discoveredProjects,
    ...
  } @ args: let
    inputDir = source;

    # Function to read and parse a TOML file and return an attrset
    # containing its path and parsed TOML value
    readToml = path: {
      inherit path;
      value = l.fromTOML (l.readFile path);
    };

    # Get the root toml
    rootToml = readToml "${inputDir}/Cargo.toml";

    # Get all workspace members
    workspaceMembers =
      l.map
      (
        memberName: let
          components = l.splitString "/" memberName;
        in
          # Resolve globs if there are any
          if l.last components == "*"
          then let
            parentDirRel = l.concatStringsSep "/" (l.init components);
            parentDir = "${inputDir}/${parentDirRel}";
            dirs = l.readDir parentDir;
          in
            l.mapAttrsToList
            (name: _: "${parentDirRel}/${name}")
            (l.filterAttrs (_: type: type == "directory") dirs)
          else memberName
      )
      (rootToml.value.workspace.members or []);
    # Get cargo packages (for workspace members)
    workspaceCargoPackages =
      l.map
      (relPath: readToml "${inputDir}/${relPath}/Cargo.toml")
      workspaceMembers;

    # All cargo packages that we will output
    cargoPackages =
      if l.hasAttrByPath ["package" "name"] rootToml.value
      # Note: the ordering is important here, since packageToml assumes
      # the rootToml to be at 0 index (if it is a package)
      then [rootToml] ++ workspaceCargoPackages
      else workspaceCargoPackages;

    # Get a "main" package toml
    packageToml = l.elemAt cargoPackages 0;

    # Figure out a package name
    packageName =
      if args.packageName == "{automatic}"
      then packageToml.value.package.name
      else args.packageName;

    # Find the base input directory, aka the root source
    baseInputDir = let
      # Find the package we are translating in discovered projects
      thisProject =
        l.findFirst (project: project.name == packageName) null discoveredProjects;
      # Default to an no suffix, since if we can't find our package in
      # discoveredProjects, it means that we are in a workspace and our
      # package will be in this workspace, so root source is inputDir
    in
      l.removeSuffix (thisProject.relPath or "") inputDir;
    # Map the list of discovered Cargo projects to cargo tomls
    discoveredCargoTomls =
      l.map (project: rec {
        value = l.fromTOML (l.readFile path);
        path = "${baseInputDir}/${project.relPath}/Cargo.toml";
      })
      discoveredProjects;
    # Filter cargo-tomls to for files that actually contain packages
    # These aren't included in the packages for the dream-lock,
    # because that would result in duplicate packages
    # Therefore, this is only used for figuring out dependencies
    # that are out of this source's path
    discoveredCargoPackages =
      l.filter
      (toml: l.hasAttrByPath ["package" "name"] toml.value)
      discoveredCargoTomls;

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
      version =
        toml.package.version
        or (l.warn "no version found in Cargo.toml for ${name}, defaulting to unknown" "unknown");
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
            (cargoPackages ++ discoveredCargoPackages)
          );
          relDir = lib.removePrefix "${inputDir}/" (l.dirOf toml.path);
        in
          if
            package.name
            == dependencyObject.name
            && package.version == dependencyObject.version
          then
            dlib.construct.pathSource {
              path = source;
              rootName = null;
              rootVersion = null;
            }
          else
            dlib.construct.pathSource {
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
