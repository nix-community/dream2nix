# fetchPip downloads python packages specified by executing
#   `pip download` on a source tree, or a list of requirements.
# This fetcher requires a maximum date 'pypiSnapshotDate' being specified.
# The result will be the same as if `pip download` would have been executed
#   at the point in time specified by pypiSnapshotDate.
# This is ensured by putting pip behind a local proxy filtering the
#   api responses from pypi.org to only contain files for which the
#   release date is lower than the specified pypiSnapshotDate.
# TODO: ignore if packages are yanked
# TODO: for pypiSnapshotDate only allow timestamp or format 2023-01-01
# TODO: Error if pypiSnapshotDate points to the future
{
  buildPackages,
  lib,
  stdenv,
  # Use the nixpkgs default python version for the proxy script.
  # The python version select by the user below might be too old for the
  #   dependencies required by the proxy
  python3,
}: {
  # Specify the python version for which the packages should be downloaded.
  # Pip needs to be executed from that specific python version.
  # Pip accepts '--python-version', but this works only for wheel packages.
  python,
  # hash for the fixed output derivation
  hash,
  # list of strings of requirements.txt entries
  requirementsList ? [],
  # list of requirements.txt files
  requirementsFiles ? [],
  # enforce source downloads for these package names
  noBinary ? [],
  # restrict to binary releases (.whl)
  # this allows buildPlatform independent fetching
  onlyBinary ? false,
  # additional flags for `pip download`.
  # for reference see: https://pip.pypa.io/en/stable/cli/pip_download/
  pipFlags ? [],
  name ? null,
  nameSuffix ? "python-requirements",
  nativeBuildInputs ? [],
  # maximum release date for packages
  pypiSnapshotDate ?
    throw ''
      'pypiSnapshotDate' must be specified for fetchPip.
      Choose any date from the past.
      Example value: "2023-01-01"
    '',
  # It's better to not refer to python.pkgs.pip directly, as we want to reduce
  #   the times we have to update the output hash
  pipVersion ? "23.0.1",
  # Write "metadata.json" to $out, including which package depends on which.
  writeMetaData ? true,
}: let
  # throws an error if pipDownload is executed with unsafe arguments
  validateArgs = result:
  # specifying `--platform` for pip download is only allowed in combination with `--only-binary :all:`
  # therefore, if onlyBinary is disabled, we must enforce targetPlatform == buildPlatform to ensure reproducibility
    if ! onlyBinary && stdenv.system != stdenv.buildPlatform.system
    then
      throw ''
        fetchPip cannot fetch sdist packages for ${stdenv.system} on a ${stdenv.buildPlatform.system}.
        Either build on a ${stdenv.system} or set `onlyBinary = true`.
      ''
    else result;

  # map nixos system strings to python platforms
  sysToPlatforms = {
    "x86_64-linux" = [
      "manylinux1_x86_64"
      "manylinux2010_x86_64"
      "manylinux2014_x86_64"
      "linux_x86_64"
    ];
    "x86_64-darwin" =
      lib.forEach (lib.range 0 15)
      (minor: "macosx_10_${builtins.toString minor}_x86_64");
    "aarch64-linux" = [
      "manylinux1_aarch64"
      "manylinux2010_aarch64"
      "manylinux2014_aarch64"
      "linux_aarch64"
    ];
  };

  platforms =
    if sysToPlatforms ? "${stdenv.system}"
    then sysToPlatforms."${stdenv.system}"
    else throw errorNoBinaryFetchingForTarget;

  errorNoBinaryFetchingForTarget = ''
    'onlyBinary' fetching is currently not supported for target ${stdenv.system}.
    You could set 'onlyBinary = false' and execute the build on a ${stdenv.system}.
  '';

  # we use mitmproxy to filter the pypi responses
  pythonWithMitmproxy =
    python3.withPackages
    (ps: [ps.mitmproxy ps.dateutil]);

  pythonWithPackaging =
    python.withPackages
    (ps: [ps.packaging ps.certifi ps.dateutil]);

  pythonMajorAndMinorVer =
    lib.concatStringsSep "."
    (lib.sublist 0 2 (lib.splitString "." python.version));

  invalidationHash = finalAttrs:
    builtins.hashString "sha256" ''

      # Ignore the python minor version. It should not affect resolution
      ${python.implementation}
      ${pythonMajorAndMinorVer}
      ${stdenv.system}

      # All variables that might influence the output
      ${finalAttrs.pypiSnapshotDate}
      ${toString finalAttrs.noBinary}
      ${finalAttrs.onlyBinaryFlags}
      ${finalAttrs.pipVersion}
      ${finalAttrs.pipFlags}
      ${toString writeMetaData}

      # Include requirements
      # We hash the content, as store paths might change more often
      ${toString finalAttrs.requirementsList}
      ${toString finalAttrs.requirementsFiles}

      # Only hash the content of the python scripts, as the store path
      # changes with every nixpkgs commit
      ${builtins.readFile finalAttrs.filterPypiResponsesScript}
      ${builtins.readFile finalAttrs.buildScript}
    '';

  invalidationHashShort = finalAttrs:
    lib.substring 0 10
    (builtins.unsafeDiscardStringContext (invalidationHash finalAttrs));

  namePrefix =
    if name == null
    then ""
    else name + "-";

  # A fixed output derivation containing all downloaded packages.
  # each single file is located inside a directory named like the package.
  # Example:
  #   "$out/werkzeug" will contain "Werkzeug-0.14.1-py2.py3-none-any.whl"
  # Each directory only ever contains a single file
  pipDownload = stdenv.mkDerivation (finalAttrs: {
    # An invalidation hash is embedded into the `name`.
    # This will prevent `forgot to update the hash` scenarios, as any change
    #   in the derivaiton name enforces a re-build.
    name = "${namePrefix}${nameSuffix}-${invalidationHashShort finalAttrs}";

    # setup FOD
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = hash;

    # Multiple outputs are not allowed in an FOD, therefore use passthru
    #   to export $dist and $names
    passthru.dist = "${finalAttrs.finalPackage}/dist";
    passthru.names = "${finalAttrs.finalPackage}/names";

    # disable some phases
    dontUnpack = true;
    dontInstall = true;
    dontFixup = true;

    # build inputs
    nativeBuildInputs = nativeBuildInputs ++ [pythonWithMitmproxy];

    # python scripts
    filterPypiResponsesScript = ./filter-pypi-responses.py;
    buildScript = ./fetchPip.py;

    # the python interpreter used to run the build script
    inherit pythonWithPackaging;

    # the python interpreter used to run the proxy script
    inherit pythonWithMitmproxy;

    # convert pypiSnapshotDate to string and integrate into finalAttrs
    pypiSnapshotDate = builtins.toString pypiSnapshotDate;

    # add some variables to the derivation to integrate them into finalAttrs
    inherit
      noBinary
      pipVersion
      requirementsFiles
      requirementsList
      writeMetaData
      ;

    # prepare flags for `pip download`
    pipFlags = lib.concatStringsSep " " pipFlags;
    onlyBinaryFlags = lib.optionalString onlyBinary "--only-binary :all: ${
      lib.concatStringsSep " " (lib.forEach platforms (pf: "--platform ${pf}"))
    }";

    # - Execute `pip download` through the filtering proxy.
    # - optionally add a file to the FOD containing metadata of the packages involved
    buildPhase = ''
      $pythonWithPackaging/bin/python $buildScript
    '';
  });
in
  validateArgs pipDownload
