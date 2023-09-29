{
  pkgs ? import <nixpkgs> {},
  lib ? import <nixpkgs/lib>,
  dream2nix ? (import (../../../modules + "/default.nix")),
  inputs ? dream2nix.inputs,
}: let
  libpdm = (import ../../../modules/dream2nix/WIP-python-pdm/lib.nix) {
    inherit lib libpyproject;
  };
  pyproject-nix = inputs.pyproject-nix;
  libpyproject = import (pyproject-nix + "/lib") {inherit lib;};

  testIsUsableSdistFilename = filename: let
    environ = libpyproject.pep508.mkEnviron pkgs.python3;
  in
    libpdm.isUsableSdistFilename {inherit environ filename;};

  # test_data = {
  # "sdist" = "certifi-2023.7.22.tar.gz";
  # ""
  # };

  tests_isUsableFilename = let
    testIsUsableWheelFilename = filename: let
      environ = libpyproject.pep508.mkEnviron pkgs.python3;
    in
      libpdm.isUsableWheelFilename {inherit environ filename;};
  in {
    test_isUsableFilename__sdist = {
      expr = testIsUsableSdistFilename "certifi-2023.7.22.tar.gz";
      expected = true;
    };

    test_isUsableFilename__wheel_universal = {
      expr = testIsUsableWheelFilename "certifi-2023.7.22-py3-none-any.whl";
      expected = true;
    };
  };

  tests_isValidUniversalWheel = let
    testIsValidUniversalWheelFilename = filename:
      libpdm.isValidUniversalWheelFilename {inherit filename;};
  in {
    test_isValidUniversalWheelFilename__wheel_universal = {
      expr = testIsValidUniversalWheelFilename "certifi-2023.7.22-py3-none-any.whl";
      expected = true;
    };

    test_isValidUniversalWheelFilename__wheel_not_universal = {
      expr = testIsValidUniversalWheelFilename "certifi-2023.7.22-py3-abi3-any.whl";
      expected = false;
    };
  };

  tests_selectExtension = let
    names = [
      "certifi-2023.7.22-py3-abi3-any.whl"
      "certifi-2023.7.22.tar.gz"
      "certifi-2023.7.22.zip"
      "certifi-2023.7.22.zip"
    ];
  in {
    test_selectExtension__tar_gz = {
      expr = libpdm.selectExtension names ".tar.gz";
      expected = "certifi-2023.7.22.tar.gz";
    };
    test_selectExtension__zip = let
      extension = ".zip";
    in {
      expr = libpdm.selectExtension names extension;
      expectedError.type = "ThrownError";
      expectedError.msg = "Multiple names found with extension ${extension}";
    };
  };

  tests_selectSdist = let
    names = [
      "certifi-2023.7.22-py3-abi3-any.whl"
      "certifi-2023.7.22.tar.gz"
      "certifi-2023.7.22.zip"
      "certifi-2023.7.22.zip"
    ];
  in {
    test_selectSdist__tar_gz = {
      expr = libpdm.selectSdist names;
      expected = "certifi-2023.7.22.tar.gz";
    };
    test_selectSdist__no_sdist = let
      names = [
        "certifi-2023.7.22-py3-abi3-any.whl"
      ];
    in {
      expr = libpdm.selectSdist names;
      expected = null;
    };
    test_selectSdist__order = let
      names = [
        "certifi-2023.7.22.zip"
        "certifi-2023.7.22.tar.gz"
      ];
    in {
      expr = libpdm.selectSdist names;
      expected = "certifi-2023.7.22.tar.gz";
    };
  };

  tests_preferWheelSelector = {
    test_preferWheelSelector__has_wheel = let
      names = [
        "certifi-2023.7.22-py3-abi3-any.whl"
        "certifi-2023.7.22.tar.gz"
        "certifi-2023.7.22.zip"
      ];
    in {
      expr = libpdm.preferWheelSelector names;
      expected = "certifi-2023.7.22-py3-abi3-any.whl";
    };
    test_preferWheelSelector__only_sdist = let
      names = [
        "certifi-2023.7.22.zip"
        "certifi-2023.7.22.tar.gz"
      ];
    in {
      expr = libpdm.preferWheelSelector names;
      expected = "certifi-2023.7.22.tar.gz";
    };
  };
  tests_preferSdistSelector = {
    test_preferSdistSelector__has_sdist = let
      names = [
        "certifi-2023.7.22-py3-abi3-any.whl"
        "certifi-2023.7.22.tar.gz"
        "certifi-2023.7.22.zip"
      ];
    in {
      expr = libpdm.preferSdistSelector names;
      expected = "certifi-2023.7.22.tar.gz";
    };
    test_preferSdistSelectorr__only_sdist = let
      names = [
        "certifi-2023.7.22.zip"
        "certifi-2023.7.22.tar.gz"
      ];
    in {
      expr = libpdm.preferSdistSelector names;
      expected = "certifi-2023.7.22.tar.gz";
    };
  };
  tests_parseLockData = let
    lock-data = lib.importTOML ./../../../examples/dream2nix-repo-flake-pdm/pdm.lock;
    version = "2023.7.22";
    parsed = libpdm.parseLockData {
      inherit lock-data;
      environ = lib.importJSON ./environ.json;
      selector = libpdm.preferWheelSelector;
    };
  in {
    test_parseLockData = {
      expr =
        (parsed ? "certifi")
        && (parsed.certifi.version == version)
        && (parsed.certifi ? source)
        && (parsed.certifi.source.url == "https://files.pythonhosted.org/packages/4c/dd/2234eab22353ffc7d94e8d13177aaa050113286e93e7b40eae01fbf7c3d9/certifi-2023.7.22-py3-none-any.whl")
        && (parsed.certifi.dependencies == []);
      expected = true;
    };
  };
in
  tests_isUsableFilename // tests_isValidUniversalWheel // tests_selectExtension // tests_selectSdist // tests_preferWheelSelector // tests_preferSdistSelector // tests_parseLockData
