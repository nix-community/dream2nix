{
  pkgs ? import <nixpkgs> {},
  lib ? import <nixpkgs/lib>,
  dream2nix ? (import ../../../.),
  inputs ? (import ../../../.).inputs,
}: let
  libpdm = (import ../../../modules/dream2nix/python-pdm/lib.nix) {
    inherit lib libpyproject;
    python3 = pkgs.python310;
    targetPlatform = lib.systems.elaborate "x86_64-linux";
  };
  inherit (inputs) pyproject-nix;
  libpyproject = import (pyproject-nix + "/lib") {inherit lib;};

  linux_environ = lib.importJSON ./environ.json;

  testIsUsableSdistFilename = filename: let
    environ = linux_environ;
  in
    libpdm.isUsableSdistFilename {inherit environ filename;};
in {
  isDependencyRequired = {
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

  isUsableFilename = let
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

  selectExtension = let
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

  selectSdist = let
    names = [
      "certifi-2023.7.22-py3-abi3-any.whl"
      "certifi-2023.7.22.tar.gz"
      "certifi-2023.7.22.zip"
      "certifi-2023.7.22.zip"
    ];
  in {
    test_tar_gz = {
      expr = libpdm.selectSdist names;
      expected = "certifi-2023.7.22.tar.gz";
    };
    test_no_sdist = let
      names = [
        "certifi-2023.7.22-py3-abi3-any.whl"
      ];
    in {
      expr = libpdm.selectSdist names;
      expected = null;
    };
    test_order = let
      names = [
        "certifi-2023.7.22.zip"
        "certifi-2023.7.22.tar.gz"
      ];
    in {
      expr = libpdm.selectSdist names;
      expected = "certifi-2023.7.22.tar.gz";
    };
  };

  selectWheel = {
    test_empty = {
      expr = libpdm.selectWheel [];
      expected = null;
    };
    test_simple_call = {
      expr = libpdm.selectWheel ["charset_normalizer-3.2.0-cp310-cp310-macosx_10_9_universal2.whl"];
      expected = null;
    };
  };

  preferWheelSelector = {
    test_has_wheel = let
      names = [
        "certifi-2023.7.22-py3-abi3-any.whl"
        "certifi-2023.7.22.tar.gz"
        "certifi-2023.7.22.zip"
      ];
    in {
      expr = libpdm.preferWheelSelector names;
      expected = "certifi-2023.7.22-py3-abi3-any.whl";
    };
    test_only_sdist = let
      names = [
        "certifi-2023.7.22.zip"
        "certifi-2023.7.22.tar.gz"
      ];
    in {
      expr = libpdm.preferWheelSelector names;
      expected = "certifi-2023.7.22.tar.gz";
    };
  };

  preferSdistSelector = {
    test_has_sdist = let
      names = [
        "certifi-2023.7.22-py3-abi3-any.whl"
        "certifi-2023.7.22.tar.gz"
        "certifi-2023.7.22.zip"
      ];
    in {
      expr = libpdm.preferSdistSelector names;
      expected = "certifi-2023.7.22.tar.gz";
    };
    test_only_sdist = let
      names = [
        "certifi-2023.7.22.zip"
        "certifi-2023.7.22.tar.gz"
      ];
    in {
      expr = libpdm.preferSdistSelector names;
      expected = "certifi-2023.7.22.tar.gz";
    };
  };

  parsePackage = {
    test_simple = {
      expr = libpdm.parsePackage linux_environ {
        name = "foo";
        version = "1.0.0";
        extras = ["extra1" "extra2"];
        requires_python = ">=3.9";
        files = [
          {
            file = "foo-1.0.0-py3-none-any.whl";
            hash = "sha256:foo";
          }
          {
            file = "foo-1.0.0.tar.gz";
            hash = "sha256:bar";
          }
        ];
        dependencies = [
          "bar[security,performance]==1.0.0"
        ];
      };
      expected = {
        name = "foo";
        version = "1.0.0";
        extras = ["extra1" "extra2"];
        dependencies = [
          {
            conditions = [
              {
                op = "==";
                version = {
                  dev = null;
                  epoch = 0;
                  local = null;
                  post = null;
                  pre = null;
                  release = [1 0 0];
                  str = "1.0.0";
                };
              }
            ];
            extras = ["security" "performance"];
            markers = null;
            name = "bar";
            url = null;
          }
        ];
        sources = {
          "foo-1.0.0-py3-none-any.whl" = {
            file = "foo-1.0.0-py3-none-any.whl";
            hash = "sha256:foo";
          };
          "foo-1.0.0.tar.gz" = {
            file = "foo-1.0.0.tar.gz";
            hash = "sha256:bar";
          };
        };
      };
    };
  };

  parseLockData = let
    lock_data = lib.importTOML ./fixtures/pdm-example1.lock;
    version = "2.31.0";
    parsed = libpdm.parseLockData {
      inherit lock_data;
      environ = linux_environ;
    };
  in {
    test_simple = {
      expr =
        (parsed ? "requests")
        && (parsed.requests.default.version == version)
        && (parsed.requests.default ? sources);
      expected = true;
    };

    test_file = {
      expr = libpdm.preferWheelSelector (lib.attrNames parsed.requests.default.sources);
      expected = "requests-2.31.0-py3-none-any.whl";
    };

    test_dependencies = {
      expr = map (dep: dep.name) parsed.requests.default.dependencies;
      expected = [
        "certifi"
        "charset-normalizer"
        "idna"
        "urllib3"
      ];
    };
    test_candidates_with_different_extras = rec {
      expr = libpdm.parseLockData {
        environ = linux_environ;
        lock_data = {
          package = [
            {
              name = "foo";
              version = "1.0.0";
              extras = [];
              dependencies = [
                "dep1==1.0.0"
              ];
              files = [
                {
                  file = "foo-1.0.0.tar.gz";
                  hash = "sha256:bar";
                }
              ];
            }
            {
              name = "foo";
              version = "1.0.0";
              extras = ["extra1" "extra2"];
              dependencies = [
                "extradep1==1.0.0"
              ];
              files = [
                {
                  file = "foo-1.0.0.tar.gz";
                  hash = "sha256:bar";
                }
              ];
            }
          ];
        };
      };
      expected = {
        foo = {
          default = {
            name = "foo";
            version = "1.0.0";
            extras = [];
            inherit (expr.foo.default) dependencies;
            inherit (expr.foo.default) sources;
          };
          "extra1,extra2" = {
            name = "foo";
            version = "1.0.0";
            extras = ["extra1" "extra2"];
            inherit (expr.foo."extra1,extra2") dependencies;
            inherit (expr.foo."extra1,extra2") sources;
          };
        };
      };
    };
  };
  groupsWithDeps = let
    environ = linux_environ;
    pyproject = libpdm.loadPdmPyProject (lib.importTOML ./fixtures/pyproject.toml);
    groups_with_deps = libpdm.groupsWithDeps {
      inherit environ pyproject;
    };
  in {
    test_has_main_group = {
      expr = groups_with_deps ? "default";
      expected = true;
    };
    test_main_group_has_deps = {
      expr = map (dep: dep.name) groups_with_deps.default;
      expected = ["requests"];
    };
    test_optionals_dev_has_deps = {
      expr = map (dep: dep.name) groups_with_deps.dev;
      expected = ["pi"];
    };
  };

  getClosure = let
    environ = linux_environ;
    lock_data_2 = lib.importTOML ./fixtures/pdm-example1.lock;
    parsed_lock_data_2 = libpdm.parseLockData {
      inherit environ;
      lock_data = lock_data_2;
    };
  in rec {
    deps = libpdm.getClosure parsed_lock_data_2 "requests" [];

    test_versions = {
      expr = lib.mapAttrs (name: dep: dep.version) deps;
      expected = {
        certifi = "2023.7.22";
        charset-normalizer = "3.2.0";
        idna = "3.4";
        urllib3 = "2.0.5";
      };
    };

    test_sources = let
      selectFilename = sources: libpdm.preferWheelSelector (lib.attrNames sources);
    in {
      expr = lib.mapAttrs (name: dep: selectFilename dep.sources) deps;
      expected = {
        certifi = "certifi-2023.7.22-py3-none-any.whl";
        charset-normalizer = "charset_normalizer-3.2.0-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
        idna = "idna-3.4-py3-none-any.whl";
        urllib3 = "urllib3-2.0.5-py3-none-any.whl";
      };
    };

    test_no_cycles = let
      lock_data = lib.importTOML ./fixtures/pdm-with-cycles.lock;
      parsed_lock_data = libpdm.parseLockData {
        inherit environ lock_data;
      };
      deps = libpdm.getClosure parsed_lock_data "pyjwt" ["crypto"];
    in {
      expr = lib.mapAttrs (name: dep: dep.version) deps;
      expected = {
        cffi = "1.16.0";
        cryptography = "41.0.7";
        pycparser = "2.21";
      };
    };

    test_closure_collects_all_extras = let
      lock_data = lib.importTOML ./fixtures/pdm-extras.lock;
      parsed_lock_data = libpdm.parseLockData {
        inherit environ lock_data;
      };
      deps = libpdm.getClosure parsed_lock_data "root" [];
    in {
      expr.foo = deps.foo.extras;
      expr.bar = deps.bar.extras;
      expected = {
        foo = ["extra1"];
        bar = ["extra2"];
      };
    };
  };

  closureForGroups = let
    environ = linux_environ;
    pyproject = libpdm.loadPdmPyProject (lib.importTOML ./fixtures/pyproject.toml);
    lock_data = lib.importTOML ./fixtures/pdm-example1.lock;
    groups_with_deps = libpdm.groupsWithDeps {
      inherit environ pyproject;
    };
    parsed_lock_data = libpdm.parseLockData {
      inherit lock_data;
      environ = linux_environ;
    };
    deps_default = libpdm.closureForGroups {
      inherit parsed_lock_data groups_with_deps;
      groupNames = ["default"];
    };
    deps_dev = libpdm.closureForGroups {
      inherit parsed_lock_data groups_with_deps;
      groupNames = ["default" "dev"];
    };
  in {
    test_names = {
      expr = lib.attrNames deps_default;
      expected = ["certifi" "charset-normalizer" "idna" "requests" "urllib3"];
    };
    test_versions = {
      expr = lib.mapAttrs (key: value: value.version) deps_default;
      expected = {
        certifi = "2023.7.22";
        charset-normalizer = "3.2.0";
        idna = "3.4";
        requests = "2.31.0";
        urllib3 = "2.0.5";
      };
    };
    test_closureForGroups_sources = let
      selectFilename = sources: libpdm.preferWheelSelector (lib.attrNames sources);
    in {
      expr = lib.mapAttrs (key: value: selectFilename value.sources) deps_default;
      expected = {
        certifi = "certifi-2023.7.22-py3-none-any.whl";
        charset-normalizer = "charset_normalizer-3.2.0-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
        idna = "idna-3.4-py3-none-any.whl";
        requests = "requests-2.31.0-py3-none-any.whl";
        urllib3 = "urllib3-2.0.5-py3-none-any.whl";
      };
    };
    test_dev_versions = {
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
}
