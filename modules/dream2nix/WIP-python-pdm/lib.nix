{
  lib,
  libpyproject,
  python3,
  targetPlatform,
}: rec {
  # Get the filename from an URL.
  # getFilename :: String -> String
  getFilename = url: lib.lists.last (lib.splitString "/" url);

  # loadPdmPyProject :: Attrset -> Attrset
  loadPdmPyProject = pyproject-data: let
    # loadPyProject does not check for existence of additional
    # paths so we need to do that here.
    tool_pdm_path = ["tool" "pdm" "dev-dependencies"];
    withPdmGroups = lib.hasAttrByPath tool_pdm_path pyproject-data;
  in
    libpyproject.project.loadPyproject ({
        pyproject = pyproject-data;
      }
      // lib.optionalAttrs withPdmGroups {
        extrasAttrPaths = [(lib.concatStringsSep "." tool_pdm_path)];
      });

  getPdmPackages = {lock_data}:
    lib.listToAttrs (
      lib.forEach lock_data.package (
        pkg:
          lib.nameValuePair pkg.name pkg
      )
    );

  # Evaluates a parsed dependency against an environment to determine if it is required.
  isDependencyRequired = environ: dependency:
    if dependency.markers != null
    then libpyproject.pep508.evalMarkers environ dependency.markers
    else true;

  # Convert sources to mapping with filename as key.
  # sourcesToAttrs :: [Attrset] -> Attrset
  sourcesToAttrs = sources:
    lib.listToAttrs (
      map (
        source:
          lib.nameValuePair source.file source
      )
      sources
    );

  isUsableFilename = {
    environ,
    filename,
  }: let
    is_wheel = libpyproject.pypa.isWheelFileName filename;
    func =
      if is_wheel
      then isUsableWheelFilename
      else isUsableSdistFilename;
  in
    func {inherit environ filename;};

  valid_sdist_extensions = [".tar.gz" ".zip"];

  # Check that the given filename is a valid sdist for our environment.
  # Note that sdist is not environment-dependent, so all we care aboutis the extension.
  isUsableSdistFilename = {
    environ, # Not needed
    filename,
  }: let
    isValidSuffix = suffix: lib.strings.hasSuffix suffix filename;
    is_valid = lib.lists.any isValidSuffix valid_sdist_extensions;
  in
    is_valid;

  # Check that the given filename is a valid wheel for our environment.
  isUsableWheelFilename = {
    environ,
    filename,
  }: let
    # TODO: implement it
    parsed_filename = libpyproject.pypa.parseWheelFileName filename;
    is_valid_build = true;
    is_valid_implementation = true;
    is_valid_abi = true;
    is_valid_platform = true;
    is_valid =
      is_valid_build
      && is_valid_implementation
      && is_valid_abi
      && is_valid_platform;
  in
    is_valid;

  # Select single item matching the extension.
  # If multiple items have the extension, raise.
  # If no items match, return null.
  # selectExtension :: [String] -> String -> String
  selectExtension = names: ext: let
    selected =
      lib.findSingle (name: lib.hasSuffix ext name) null "multiple" names;
  in
    if selected == "multiple"
    then throw "Multiple names found with extension ${ext}"
    else selected;

  # Select a single sdist from a list of filenames.
  # If multiple sdist we choose the preferred sdist.
  # If no valid sdist present we return null.
  # selectSdist :: [String] -> String
  selectSdist = filenames: let
    select = selectExtension filenames;
    selection = map select valid_sdist_extensions;
    selected = lib.findFirst (name: name != null) null selection;
  in
    selected;

  # Select a single wheel from a list of filenames
  # This assumes filtering on usable wheels has already been performed.
  # selectWheel :: [String] ->  String
  selectWheel = files: let
    wheelFiles = lib.filter libpyproject.pypa.isWheelFileName files;
    wheels = map libpyproject.pypa.parseWheelFileName wheelFiles;
    selected =
      libpyproject.pypa.selectWheels
      targetPlatform
      python3
      wheels;
  in (
    if lib.length selected == 0
    then null
    else (lib.head selected).filename
  );

  # Source selectors.
  # Prefer to select a wheel from a list of filenames.
  # Filenames should already have been filtered on environment usability.
  # preferWheelSelector :: [String] -> String
  preferWheelSelector = filenames: let
    wheel = selectWheel filenames;
    sdist = selectSdist filenames;
  in
    if wheel != null
    then wheel
    else if sdist != null
    then sdist
    else null;

  # preferSdistSelector :: [String] -> String
  preferSdistSelector = filenames: let
    wheel = selectWheel filenames;
    sdist = selectSdist filenames;
  in
    if sdist != null
    then sdist
    else if wheel != null
    then wheel
    else null;

  # Get the dependency names out from a list of parsed deps which are
  #   required due to the current environment.
  # requiredDeps :: Attrset -> [Attrset] -> [String]
  requiredDeps = environ: parsed_deps: let
    requiredDeps' = lib.filter (isDependencyRequired environ) parsed_deps;
  in
    requiredDeps';

  # TODO: validate against lock file version.
  parsePackage = environ: item: let
    sources = sourcesToAttrs item.files;
    compatibleSources =
      lib.filterAttrs
      (
        filename: source:
          isUsableFilename {inherit environ filename;}
      )
      sources;
    parsedDeps = map libpyproject.pep508.parseString item.dependencies or [];
  in {
    inherit (item) name version;
    extras = item.extras or [];
    dependencies = requiredDeps environ parsedDeps;
    sources = compatibleSources;
    # In the future we could add additional meta data fields
    # such as summary
  };

  # Create a string identified for a set of extras.
  mkExtrasKey = dep @ {extras ? [], ...}:
    if extras == []
    then "default"
    else lib.concatStringsSep "," extras;

  # Constructs dependency entry for internal use.
  # We could use the pyproject.nix representation directly instead, but it seems
  #   easier to test this code if we only keep the data we need.
  mkDepEntry = parsed_lock_data: dep @ {
    name,
    extras,
    ...
  }: {
    extras = extras;
    sources = parsed_lock_data.${name}.${mkExtrasKey {inherit extras;}}.sources;
    version = parsed_lock_data.${name}.${mkExtrasKey {inherit extras;}}.version;
  };

  # Parse lockfile data.
  # Returns a set with package name as key
  # and as value the version, sources and dependencies
  # The packages are not yet divided into groups.
  parseLockData = {
    lock_data,
    environ, # Output from `libpyproject.pep508.mkEnviron`
  }:
    lib.foldl
    (acc: dep:
      acc
      // {
        "${dep.name}" =
          acc.${dep.name}
          or {}
          // {
            "${mkExtrasKey dep}" = dep;
          };
      })
    {}
    (map (parsePackage environ) lock_data.package);

  # Create an overview of all groups and dependencies
  # Keys are group names, and values lists with strings.
  # groupsWithDeps :: { Attrset, Attrset} -> Attrset
  groupsWithDeps = {
    pyproject,
    environ,
  }: let
    # TODO: it is possible to use PDM without a main project
    # so there would not be any default group.
    requiredDeps' = requiredDeps environ;
    default = requiredDeps' pyproject.dependencies.dependencies;
    # The extras field contains both `project.optional-dependencies` and
    # `tool.pdm.dev-dependencies`.
    optional_dependencies =
      lib.mapAttrs
      (name: value: requiredDeps' value)
      pyproject.dependencies.extras;

    all_groups = {inherit default;} // optional_dependencies;
  in
    all_groups;

  # Get a set with all transitive dependencies flattened.
  # For every dependency we have the version, sources and extras.
  # getClosure :: Attrset -> String -> [String] -> Attrset
  getClosure = parsed_lock_data: name: extras: let
    closure = builtins.genericClosure {
      startSet = [
        {
          key = "${name}#${mkExtrasKey {inherit extras;}}";
          value = parsed_lock_data.${name}.${mkExtrasKey {inherit extras;}};
        }
      ];
      operator = item:
        lib.forEach item.value.dependencies or [] (dep: {
          key = "${dep.name}#${mkExtrasKey dep}";
          value = parsed_lock_data.${dep.name}.${mkExtrasKey dep};
        });
    };

    # mapping of all dependencies by name with merged extras.
    depsByNames =
      lib.foldl'
      (
        acc: x: let
          dep = x.value;
        in
          acc
          // {
            "${dep.name}" =
              acc.${dep.name}
              or {}
              // {
                extras =
                  lib.sort (x: y: x > y)
                  (lib.unique (acc.${dep.name}.extras or [] ++ dep.extras));
                version = dep.version;
                sources = dep.sources;
              };
          }
      )
      {}
      closure;
  in
    # remove self references from the closure to prevent cycles
    builtins.removeAttrs depsByNames [name];

  # Compute the dependency closure for the given groups.
  # closureForGroups :: {Attrset, Attrset, String}
  closureForGroups = {
    parsed_lock_data,
    groups_with_deps,
    groupNames,
  }: let
    # List of all top-level dependencies for the given groups.
    deps_top_level =
      lib.concatMap
      (groupName: groups_with_deps.${groupName})
      groupNames;
    # Top-level dependencies in expected format.
    #   Children are already returned in correct format by 'getClosure'.
    topLevelEntries =
      map
      (dep: {
        name = dep.name;
        value = mkDepEntry parsed_lock_data dep;
      })
      deps_top_level;
    # helper to get the closure for a single dependency.
    getClosureForDep = dep: getClosure parsed_lock_data dep.name dep.extras;
  in
    # top-level dependencies
    (lib.listToAttrs topLevelEntries)
    # transitive dependencies
    // (lib.attrsets.mergeAttrsList (map getClosureForDep deps_top_level));
}
