# fetchPipMetadata downloads python packages specified by executing
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
  lib,
  writeText,
  # Use the nixpkgs default python version for the proxy script.
  # The python version select by the user below might be too old for the
  #   dependencies required by the proxy
  python3,
  # Specify the python version for which the packages should be downloaded.
  # Pip needs to be executed from that specific python version.
  # Pip accepts '--python-version', but this works only for wheel packages.
  pythonInterpreter,
  # list of strings of requirements.txt entries
  requirementsList ? [],
  # list of requirements.txt files
  requirementsFiles ? [],
  pipFlags ? [],
  pipVersion ? "23.1",
  env ? {},
  wheelVersion ? "0.40.0",
  nativeBuildInputs ? [],
  # maximum release date for packages
  pypiSnapshotDate ? null,
  # executable that returns the project root
  findRoot,
  nix,
  gitMinimal,
  writePureShellScript,
  nix-prefetch-scripts,
  openssh,
  fetchFromGitHub,
  fetchurl,
  rustPlatform,
}: let
  package = import ./package.nix {
    inherit
      lib
      python3
      gitMinimal
      nix-prefetch-scripts
      ;
  };

  pythonFixed = python3.override {
    packageOverrides = curr: prev: {
      /*
      downgrading to version 10.1.*, as 10.2.0 introduces a breakage triggering:
        [17:42:11.824][[::1]:56958] client connect
        [17:42:11.909][[::1]:56958] server connect pypi.org:443 (151.101.64.223:443)
        [17:42:11.958] Deferring layer decision, not enough data: [...]
      */

      aioquic-mitmproxy = curr.callPackage ./aioquic-mitmproxy.nix {};
      urwid-mitmproxy = curr.callPackage ./urwid-mitmproxy.nix {};

      mitmproxy = curr.callPackage ./mitmproxy.nix {};

      # mitmproxy = prev.mitmproxy.overridePythonAttrs (old: rec {
      #   version = "10.1.6";
      #   src = fetchFromGitHub {
      #     owner = "mitmproxy";
      #     repo = "mitmproxy";
      #     rev = "refs/tags/${version}";
      #     hash = "sha256-W+gxK5bNCit1jK9ojwE/HVjUz6OJcNw6Ac1lN5FxGgw=";
      #   };
      #   doCheck = false;
      #   pyproject = true;
      #   pythonRelaxDeps = [
      #     "pyopenssl"
      #     "cryptography"
      #   ];
      #   propagatedBuildInputs = [
      #     curr.aioquic-mitmproxy
      #   ];
      # });
      mitmproxy-rs = prev.mitmproxy-rs.overrideAttrs (old: rec {
        version = "0.4.1";
        src = fetchFromGitHub {
          owner = "mitmproxy";
          repo = "mitmproxy_rs";
          rev = version;
          hash = "sha256-Vc7ez/W40CefO2ZLAHot14p478pDPtQor865675vCtI=";
        };
        cargoDeps = rustPlatform.importCargoLock {
          lockFile = "${src}/Cargo.lock";
          outputHashes = {
            "internet-packet-0.1.0" = "sha256-VtEuCE1sulBIFVymh7YW7VHCuIBjtb6tHoPz2tjxX+Q=";
          };
        };
      });

      mitmproxy-macos = prev.buildPythonPackage rec {
        pname = "mitmproxy-macos";
        version = "0.4.1";
        format = "wheel";

        src = fetchurl {
          url = "https://files.pythonhosted.org/packages/85/79/f11ba4cf6e89408ed52d9317c00d3ae4ad18c51cf710821c9342fc95cd0f/mitmproxy_macos-0.5.1-py3-none-any.whl";
          hash = "sha256-P7T8mTCzMQEphnWuumZF3ucb4XYgyMsHyBC6i+1sKkI=";
        };

        pythonImportsCheck = ["mitmproxy_macos"];
        nativeBuildInputs = [
          prev.hatchling
        ];
      };
    };
  };

  # We use nixpkgs python3 to run mitmproxy, see function parameters
  pythonWithMitmproxy =
    pythonFixed.withPackages
    (ps: [ps.mitmproxy ps.python-dateutil]);

  path = [nix gitMinimal openssh] ++ nativeBuildInputs;

  args = writeText "pip-args" (builtins.toJSON {
    # convert pypiSnapshotDate to string and integrate into finalAttrs
    pypiSnapshotDate =
      if pypiSnapshotDate == null
      then null
      else builtins.toString pypiSnapshotDate;

    filterPypiResponsesScript =
      if pypiSnapshotDate == null
      then null
      else ./filter-pypi-responses.py;

    # the python interpreter used to run the proxy script
    mitmProxy =
      if pypiSnapshotDate == null
      then null
      else "${pythonWithMitmproxy}/bin/mitmdump";

    # add some variables to the derivation to integrate them into finalAttrs
    inherit
      pipVersion
      pipFlags
      pythonInterpreter
      requirementsFiles
      requirementsList
      wheelVersion
      ;
  });

  script =
    writePureShellScript
    path
    ''
      ${
        lib.foldlAttrs
        (acc: name: value: acc + "\nexport " + lib.toShellVar name value)
        ""
        env
      }
      ${package}/bin/fetch_pip_metadata \
        --json-args-file ${args} \
        --project-root $(${findRoot})
    '';
in
  script
