{
  lib,
  libpyproject,
}: rec {
  # getFilename :: String -> String
  getFilename = url: lib.lists.last (lib.splitString "/" url);

  getPdmPackages = {lock-data}:
    lib.listToAttrs (
      lib.forEach lock-data.package (
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
          lib.nameValuePair (getFilename source.file) source
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
    is_valid = parsed_filename.languageTag == "py3" && parsed_filename.abiTag == "none" && parsed_filename.platformTags == ["any"];
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
    is_valid = is_valid_build && is_valid_implementation && is_valid_abi && is_valid_platform;
  in
    is_valid;

  # Select single item matching the extension.
  # If multiple items have the extension, raise.
  # If no items match, return null.
  # selectExtension :: [String] -> String -> String
  selectExtension = names: ext: let
    selected = lib.findSingle (name: lib.hasSuffix ext name) null "multiple" names;
  in
    if selected == "multiple"
    then throw "Multiple names found with extension ${ext}"
    else selected;

  # Select a single sdist from a list of filenames.
  # If multiple sdist we choose the preferred sdist.
  # If no valid sdist present we return null.
  # selectSdist :: [String] -> String
  selectSdist = filenames: let
    # sdists = lib.filter (filename: isUsableSdistFilename {environ = {}; inherit filename;}) filenames;
    select = selectExtension filenames;
    selection = map select valid_sdist_extensions;
    selected = lib.findFirst (name: name != null) null selection;
  in
    selected;

  # Select a single wheel from a list of filenames
  # This assumes filtering on usable wheels has already been performed.
  # selectWheel :: [String] ->  String
  selectWheel = filenames: lib.findFirst (x: lib.hasSuffix ".whl" x) null filenames;

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

  # Parse lockfile data.
  # Returns a set with package name as key
  # and as value the version, sources and dependencies
  # The packages are not yet divided into groups.
  parseLockData = {
    lock-data,
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
      parsedDeps = (
        map
        libpyproject.pep508.parseString
        item.dependencies or []
      );
      requiredDeps = lib.filter (isDependencyRequired environ) parsedDeps;
      value = {
        dependencies = map (dep: dep.name) requiredDeps;
        inherit (item) version;
        source = sources.${selector (lib.attrNames compatibleSources)};
        # In the future we could add additional meta data fields
        # such as summary
      };
    in
      lib.nameValuePair item.name value;
  in
    # TODO: packages need to be filtered on environment.
    lib.listToAttrs (map parsePackage lock-data.package);
}
