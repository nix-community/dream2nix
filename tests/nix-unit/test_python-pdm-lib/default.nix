{
  pkgs ? import <nixpkgs> {},
  lib ? import <nixpkgs/lib>,
  dream2nix ? (import (../../../modules + "/flake.nix")).outputs inputs,
  inputs ? (import (../../../modules + "/default.nix")).inputs,
}: let
  libpdm = (import ../../../modules/dream2nix/WIP-python-pdm/lib.nix) {
    inherit lib libpyproject;
  };
  pyproject-nix = inputs.pyproject-nix;
  libpyproject = import (pyproject-nix + "/lib") {inherit lib;};

  linux_environ = lib.importJSON ./environ.json;

  test_isDependencyRequired = {
    test_isDependencyRequired__not_required = {
      expr =
        libpdm.isDependencyRequired
        linux_environ
        (libpyproject.pep508.parseString "foo==1.0.0; sys_platform == 'win32'");
      expected = false;
    };
    test_isDependencyRequired__required = {
      expr =
        libpdm.isDependencyRequired
        linux_environ
        (libpyproject.pep508.parseString "foo==1.0.0; sys_platform == 'linux'");
      expected = true;
    };
  };

  testIsUsableSdistFilename = filename: let
    environ = linux_environ;
  in
    libpdm.isUsableSdistFilename {inherit environ filename;};

  tests_isUsableFilename = let
    testIsUsableWheelFilename = filename: let
      environ = linux_environ;
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
    lock_data = lib.importTOML ./../../../examples/repo-flake-pdm/pdm.lock;
    version = "2.31.0";
    parsed = libpdm.parseLockData {
      inherit lock_data;
      environ = linux_environ;
      selector = libpdm.preferWheelSelector;
    };
  in {
    test_parseLockData = {
      expr =
        (parsed ? "requests")
        && (parsed.requests.version == version)
        && (parsed.requests ? source);
      expected = true;
    };

    test_parseLockData_file = {
      expr = parsed.requests.source.file;
      expected = "requests-2.31.0-py3-none-any.whl";
    };

    test_parseLockData_dependencies = {
      expr = parsed.requests.dependencies;
      expected = [
        "certifi"
        "charset-normalizer"
        "idna"
        "urllib3"
      ];
    };
  };
  tests_groupsWithDeps = let
    environ = linux_environ;
    pyproject = libpdm.loadPdmPyProject (lib.importTOML ./../../../examples/repo-flake-pdm/pyproject.toml);
    groups_with_deps = libpdm.groupsWithDeps {
      inherit environ pyproject;
    };
  in {
    test_groupsWithDeps__has_main_group = {
      expr = groups_with_deps ? "default";
      expected = true;
    };
    test_groupsWithDeps__main_group_has_deps = {
      expr = groups_with_deps.default;
      expected = ["requests"];
    };
    test_groupsWithDeps__optionals_dev_has_deps = {
      expr = groups_with_deps.dev;
      expected = ["pi"];
    };
  };

  tests_getDepsRecursively = let
    environ = linux_environ;
    lock_data = lib.importTOML ./../../../examples/repo-flake-pdm/pdm.lock;
    parsed_lock_data = libpdm.parseLockData {
      inherit environ lock_data;
      selector = libpdm.preferWheelSelector;
    };
    deps = libpdm.getDepsRecursively parsed_lock_data "requests";
  in {
    test_getDepsRecursively_names = {
      expr = lib.attrNames deps;
      expected = ["certifi" "charset-normalizer" "idna" "requests" "urllib3"];
    };
    test_getDepsRecursively_versions = {
      expr = lib.mapAttrs (key: value: value.version) deps;
      expected = {
        certifi = "2023.7.22";
        charset-normalizer = "3.2.0";
        idna = "3.4";
        requests = "2.31.0";
        urllib3 = "2.0.5";
      };
    };
    test_getDepsRecursively_sources = {
      expr = lib.mapAttrs (key: value: value.source.file) deps;
      expected = {
        certifi = "certifi-2023.7.22-py3-none-any.whl";
        charset-normalizer = "charset_normalizer-3.2.0-cp310-cp310-macosx_10_9_universal2.whl";
        idna = "idna-3.4-py3-none-any.whl";
        requests = "requests-2.31.0-py3-none-any.whl";
        urllib3 = "urllib3-2.0.5-py3-none-any.whl";
      };
    };
  };

  tests_selectForGroups = let
    environ = linux_environ;
    pyproject = libpdm.loadPdmPyProject (lib.importTOML ./../../../examples/repo-flake-pdm/pyproject.toml);
    lock_data = lib.importTOML ./../../../examples/repo-flake-pdm/pdm.lock;
    groups_with_deps = libpdm.groupsWithDeps {
      inherit environ pyproject;
    };
    parsed_lock_data = libpdm.parseLockData {
      inherit lock_data;
      environ = linux_environ;
      selector = libpdm.preferWheelSelector;
    };
    deps_default = libpdm.selectForGroups {
      inherit parsed_lock_data groups_with_deps;
      groupNames = ["default"];
    };
    deps_dev = libpdm.selectForGroups {
      inherit parsed_lock_data groups_with_deps;
      groupNames = ["default" "dev"];
    };
  in {
    test_selectForGroups_names = {
      expr = lib.attrNames deps_default;
      expected = ["certifi" "charset-normalizer" "idna" "requests" "urllib3"];
    };
    test_selectForGroups_versions = {
      expr = lib.mapAttrs (key: value: value.version) deps_default;
      expected = {
        certifi = "2023.7.22";
        charset-normalizer = "3.2.0";
        idna = "3.4";
        requests = "2.31.0";
        urllib3 = "2.0.5";
      };
    };
    test_selectForGroups_sources = {
      expr = lib.mapAttrs (key: value: value.source.file) deps_default;
      expected = {
        certifi = "certifi-2023.7.22-py3-none-any.whl";
        charset-normalizer = "charset_normalizer-3.2.0-cp310-cp310-macosx_10_9_universal2.whl";
        idna = "idna-3.4-py3-none-any.whl";
        requests = "requests-2.31.0-py3-none-any.whl";
        urllib3 = "urllib3-2.0.5-py3-none-any.whl";
      };
    };
    test_selectForGroups_dev_versions = {
      expr = lib.mapAttrs (key: value: value.version) deps_dev;
      expected = {
        certifi = "2023.7.22";
        charset-normalizer = "3.2.0";
        idna = "3.4";
        requests = "2.31.0";
        urllib3 = "2.0.5";
        pi = "0.1.2";
      };
    };
  };
in
  test_isDependencyRequired // tests_isUsableFilename // tests_selectExtension // tests_selectSdist // tests_preferWheelSelector // tests_preferSdistSelector // tests_parseLockData // tests_groupsWithDeps // tests_getDepsRecursively // tests_selectForGroups
