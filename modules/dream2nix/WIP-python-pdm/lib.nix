{
  lib,
  libpyproject,
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
    is_wheel = libpyproject.pep427.isWheelFileName filename;
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

  # matchUniversalWheelFileName = lib.match "([^-]+)-([^-]+)(-([[:digit:]][^-]*))?-([^-]+)-([^-]+)-(.+).[tar.gz|zip]";
  # name: matchUniversalWheelFileName name != null;

  isValidUniversalWheelFilename = {filename}: let
    parsed_filename = libpyproject.pep427.parseFileName filename;
    is_valid =
      (parsed_filename.languageTag == "py3")
      && (parsed_filename.abiTag == "none")
      && (parsed_filename.platformTags == ["any"]);
  in
    is_valid;

  # Check that the given filenameis a valid wheel for our environment.
  isUsableWheelFilename = {
    environ,
    filename,
  }: let
    # TODO: implement it
    parsed_filename = libpyproject.pep427.parseFileName filename;
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
  selectWheel = filenames:
    lib.findFirst (x: lib.hasSuffix ".whl" x) null filenames;

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

  # Get the dependency names out from a list of parsed deps
  # requiredDeps :: Attrset -> [Attrset] -> [String]
  requiredDeps = environ: parsed_deps: let
    requiredDeps' = lib.filter (isDependencyRequired environ) parsed_deps;
  in
    map (dep: dep.name) requiredDeps';

  # Parse lockfile data.
  # Returns a set with package name as key
  # and as value the version, sources and dependencies
  # The packages are not yet divided into groups.
  parseLockData = {
    lock_data,
    environ, # Output from `libpyproject.pep508.mkEnviron`
    selector,
  }: let
    # TODO: validate against lock file version.
    parsePackage = item: let
      sources = sourcesToAttrs item.files;
      compatibleSources =
        lib.filterAttrs
        (
          filename: source:
            isUsableFilename {inherit environ filename;}
        )
        sources;
      parsedDeps = with lib.trivial; (
        map
        ((flip pipe) [
          lib.strings.toLower
          libpyproject.pep508.parseString
        ])
        item.dependencies or []
      );
      value = {
        dependencies = requiredDeps environ parsedDeps;
        inherit (item) version;
        source = sources.${selector (lib.attrNames compatibleSources)};
        # In the future we could add additional meta data fields
        # such as summary
      };
    in
      lib.nameValuePair item.name value;
  in
    # TODO: packages need to be filtered on environment.
    lib.listToAttrs (map parsePackage lock_data.package);

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
  # For every dependency we have the version, source
  # and dependencies as names.
  # getDepsRecursively :: Attrset -> String -> Attrset
  getDepsRecursively = parsedLockData: name: let
    getDeps = name: let
      dep = parsedLockData.${name};
    in
      [{"${name}" = dep;}] ++ lib.flatten (map getDeps dep.dependencies);
  in
    lib.attrsets.mergeAttrsList (lib.unique (getDeps name));

  # Select the dependencies we need in our group.
  # Here we recurse so we get a set with all dependencies.
  # selectForGroup :: {Attrset, Attrset, String}
  selectForGroup = {
    parsed_lock_data,
    groups_with_deps,
    groupname,
  }: let
    # List of top-level package names we need.
    deps_top_level = groups_with_deps.${groupname};
    getDeps = getDepsRecursively parsed_lock_data;
  in
    lib.attrsets.mergeAttrsList (map getDeps deps_top_level);
}
