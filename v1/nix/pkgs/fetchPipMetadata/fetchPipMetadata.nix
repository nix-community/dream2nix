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
  stdenv,
  lib,
  writers,
  writeText,
  writeShellScriptBin,
  makeWrapper,
  symlinkJoin,
  # Use the nixpkgs default python version for the proxy script.
  # The python version select by the user below might be too old for the
  #   dependencies required by the proxy
  python3,
}: {
  # Specify the python version for which the packages should be downloaded.
  # Pip needs to be executed from that specific python version.
  # Pip accepts '--python-version', but this works only for wheel packages.
  python,
  # list of strings of requirements.txt entries
  requirementsList ? [],
  # list of requirements.txt files
  requirementsFiles ? [],
  pipFlags ? [],
  pipVersion ? "22.3.1",
  nativeBuildInputs ? [],
  # maximum release date for packages
  pypiSnapshotDate ?
    throw ''
      'pypiSnapshotDate' must be specified for fetchPip.
      Choose any date from the past.
      Example value: "2023-01-01"
    '',
  nix,
  git,
}: let
  # We use nixpkgs python3 to run mitmproxy, see function parameters
  pythonWithMitmproxy =
    python3.withPackages
    (ps: [ps.mitmproxy ps.python-dateutil]);

  # We use the user-selected python to run pip and friends, this ensures
  # that version-related markers are resolved correctly.
  writePython = writers.makePythonWriter python python.pkgs python.pkgs;

  fetchPipMetadata =
    writePython
    "fetch_pip_metadata"
    {libraries = with python.pkgs; [packaging certifi python-dateutil pip];}
    ./fetchPipMetadata.py;

  args = writeText "pip-args" (builtins.toJSON {
    filterPypiResponsesScript = ../fetchPip/filter-pypi-responses.py;
    buildScript = ./fetchPipMetadata.py;

    # the python interpreter used to run the proxy script
    mitmProxy = "${pythonWithMitmproxy}/bin/mitmdump";

    # convert pypiSnapshotDate to string and integrate into finalAttrs
    pypiSnapshotDate = builtins.toString pypiSnapshotDate;

    # add some variables to the derivation to integrate them into finalAttrs
    inherit
      requirementsFiles
      requirementsList
      pipVersion
      pipFlags
      ;
  });
  script = writeShellScriptBin "fetch_pip_metadata" ''
    ${fetchPipMetadata} ${args}
  '';
  env = symlinkJoin {
    name = "fetch_pip_metadata";
    paths = [script nix git] ++ nativeBuildInputs;
    buildInputs = [makeWrapper];
    postBuild = "wrapProgram $out/bin/fetch_pip_metadata --prefix PATH : $out/bin";
  };
in "${env}/bin/fetch_pip_metadata"
