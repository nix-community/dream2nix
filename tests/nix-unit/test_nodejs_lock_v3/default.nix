{
  pkgs ? import <nixpkgs> {},
  lib ? import <nixpkgs/lib>,
  dream2nix ? (import (../../../modules + "/flake.nix")).outputs {},
}: let
  eval = module:
    lib.evalModules {
      modules = [module];
      specialArgs = {
        inherit dream2nix;
        packageSets = {
          nixpkgs = pkgs;
        };
      };
    };
in {
  # test if dependencies are ignored successfully in pip.rootDependencies
  test_nodejs_parse_root_lock = let
    evaled = eval {
      imports = [
        dream2nix.modules.dream2nix.nodejs-package-lock-v3
      ];
      nodejs-package-lock-v3.packageLock = lib.mkForce {
        # Example content of lockfile
        "name" = "minimal";
        "version" = "1.0.0";
        "lockfileVersion" = 3;
        "requires" = true;
        "packages" = {
          "" = {
            "name" = "minimal";
            "version" = "1.0.0";
            "license" = "ISC";
            "dependencies" = {
            };
          };
        };
      };
      # This needs to be set by the user / we can set this automatically later
      nodejs-package-lock-v3.pdefs."minimal"."1.0.0".source = "";
    };
    config = evaled.config;
  in {
    expr = config.nodejs-package-lock-v3.pdefs;
    expected = {
      "minimal"."1.0.0" = {
        dependencies = {};
        source = "";
      };
    };
  };

  # test if dependencies are ignored successfully in pip.rootDependencies
  test_nodejs_fetch_dep = let
    evaled = eval {
      imports = [
        dream2nix.modules.dream2nix.nodejs-package-lock-v3
      ];
      nodejs-package-lock-v3.packageLock = lib.mkForce {
        # Example content of lockfile
        "name" = "minimal";
        "version" = "1.0.0";
        "lockfileVersion" = 3;
        "requires" = true;
        "packages" = {
          "node_modules/async" = {
            "version" = "0.2.10";
            "resolved" = "https://registry.npmjs.org/async/-/async-0.2.10.tgz";
            "integrity" = "sha512-eAkdoKxU6/LkKDBzLpT+t6Ff5EtfSF4wx1WfJiPEEV7WNLnDaRXk0oVysiEPm262roaachGexwUv94WhSgN5TQ==";
          };
        };
      };
    };
    config = evaled.config;
  in {
    expr = "${config.nodejs-package-lock-v3.pdefs."async"."0.2.10".source}";
    expected = "/nix/store/sm4v0qaynkjf704lrcqxhlssp003y9h8-async-0.2.10.tgz";
  };

  # test if dependencies are ignored successfully in pip.rootDependencies
  test_nodejs_file_dep = let
    evaled = eval {
      imports = [
        dream2nix.modules.dream2nix.nodejs-package-lock-v3
      ];
      nodejs-package-lock-v3.packageLockFile = ./package-lock.json;
      nodejs-package-lock-v3.packageLock = lib.mkForce {
        # Example content of lockfile
        "name" = "minimal";
        "version" = "1.0.0";
        "lockfileVersion" = 3;
        "requires" = true;
        "packages" = {
          "node_modules/@org/lib" = {
            "resolved" = "./lib";
            "link" = true;
          };
          "node_modules/@org/async" = {
            "version" = "0.2.10";
            "resolved" = "https://registry.npmjs.org/async/-/async-0.2.10.tgz";
            "integrity" = "sha512-eAkdoKxU6/LkKDBzLpT+t6Ff5EtfSF4wx1WfJiPEEV7WNLnDaRXk0oVysiEPm262roaachGexwUv94WhSgN5TQ==";
          };
        };
      };
    };
    config = evaled.config;
  in {
    expr = config.nodejs-package-lock-v3.pdefs."@org/lib"."1.0.0".source;
    expected = ./. + "/lib";
  };

  # test if dependencies are ignored successfully in pip.rootDependencies
  test_nodejs_resolve_single_dependency = let
    evaled = eval {
      imports = [
        dream2nix.modules.dream2nix.nodejs-package-lock-v3
      ];
      nodejs-package-lock-v3.packageLockFile = ./package-lock.json;
      nodejs-package-lock-v3.packageLock = lib.mkForce {
        # Example content of lockfile
        "name" = "minimal";
        "version" = "1.0.0";
        "lockfileVersion" = 3;
        "requires" = true;
        "packages" = {
          "" = {
            "name" = "minimal";
            "version" = "1.0.0";
            "license" = "ISC";
            "dependencies" = {
              "@org/async" = "^0.2.0";
            };
          };
          "node_modules/@org/async" = {
            "version" = "0.2.10";
            "resolved" = "https://registry.npmjs.org/async/-/async-0.2.10.tgz";
            "integrity" = "sha512-eAkdoKxU6/LkKDBzLpT+t6Ff5EtfSF4wx1WfJiPEEV7WNLnDaRXk0oVysiEPm262roaachGexwUv94WhSgN5TQ==";
          };
        };
      };
    };
    config = evaled.config;
  in {
    expr = config.nodejs-package-lock-v3.pdefs."minimal"."1.0.0".dependencies;
    expected = {
      "@org/async" = {
        dev = false;
        version = "0.2.10";
      };
    };
  };

  test_nodejs_resolve_nested_dependency = let
    evaled = eval {
      imports = [
        dream2nix.modules.dream2nix.nodejs-package-lock-v3
      ];
      nodejs-package-lock-v3.packageLockFile = ./package-lock.json;
      nodejs-package-lock-v3.packageLock = lib.mkForce {
        # Example content of lockfile
        "name" = "minimal";
        "version" = "1.0.0";
        "lockfileVersion" = 3;
        "requires" = true;
        "packages" = {
          "node_modules/foo" = {
            "version" = "1.0.0";
            "dependencies" = {
              "@org/async" = "^0.2.10";
            };
          };
          # expect to resolve this
          "node_modules/foo/node_modules/@org/async" = {
            "version" = "0.2.10";
            "resolved" = "https://registry.npmjs.org/async/-/async-0.2.10.tgz";
            "integrity" = "sha512-eAkdoKxU6/LkKDBzLpT+t6Ff5EtfSF4wx1WfJiPEEV7WNLnDaRXk0oVysiEPm262roaachGexwUv94WhSgN5TQ==";
          };
          # expect to NOT resolve this
          "node_modules/@org/async" = {
            "version" = "1.0.0";
            "resolved" = "https://registry.npmjs.org/async/-/async-0.2.10.tgz";
            "integrity" = "sha512-eAkdoKxU6/LkKDBzLpT+t6Ff5EtfSF4wx1WfJiPEEV7WNLnDaRXk0oVysiEPm262roaachGexwUv94WhSgN5TQ==";
          };
        };
      };
    };
    config = evaled.config;
  in {
    expr = config.nodejs-package-lock-v3.pdefs."foo"."1.0.0".dependencies;
    expected = {
      "@org/async" = {
        dev = false;
        version = "0.2.10";
      };
    };
  };

  test_nodejs_resolve_hoisted_dependency = let
    evaled = eval {
      imports = [
        dream2nix.modules.dream2nix.nodejs-package-lock-v3
      ];
      nodejs-package-lock-v3.packageLockFile = ./package-lock.json;
      nodejs-package-lock-v3.packageLock = lib.mkForce {
        # Example content of lockfile
        "name" = "minimal";
        "version" = "1.0.0";
        "lockfileVersion" = 3;
        "packages" = {
          "node_modules/foo" = {
            "version" = "1.0.0";
            "dependencies" = {
              "@org/async" = "^0.2.10";
            };
          };
          # expect to NOT resolve this
          "node_modules/other/node_modules/@org/async" = {
            "version" = "1.0.0";
          };
          # expect to resolve this
          "node_modules/@org/async" = {
            "version" = "0.2.10";
          };
        };
      };
    };
    config = evaled.config;
  in {
    expr = config.nodejs-package-lock-v3.pdefs."foo"."1.0.0".dependencies;
    expected = {
      "@org/async" = {
        dev = false;
        version = "0.2.10";
      };
    };
  };

  test_nodejs_resolve_dev_dependency = let
    evaled = eval {
      imports = [
        dream2nix.modules.dream2nix.nodejs-package-lock-v3
      ];
      nodejs-package-lock-v3.packageLockFile = ./package-lock.json;
      nodejs-package-lock-v3.packageLock = lib.mkForce {
        # Example content of lockfile
        "name" = "minimal";
        "version" = "1.0.0";
        "lockfileVersion" = 3;
        "packages" = {
          "node_modules/foo" = {
            "version" = "1.0.0";
            "devDependencies" = {
              "@org/async" = "^0.2.10";
            };
          };
          # expect to NOT resolve this
          "node_modules/other/node_modules/@org/async" = {
            "version" = "1.0.0";
          };
          # expect to resolve this
          "node_modules/@org/async" = {
            "version" = "0.2.10";
          };
        };
      };
    };
    config = evaled.config;
  in {
    expr = config.nodejs-package-lock-v3.pdefs."foo"."1.0.0".dependencies;
    expected = {
      "@org/async" = {
        dev = false;
        version = "0.2.10";
      };
    };
  };

  test_multiple_versions = let
    evaled = eval {
      imports = [
        dream2nix.modules.dream2nix.nodejs-package-lock-v3
      ];
      nodejs-package-lock-v3.packageLockFile = ./multiple-versions-lock.json;
    };
    config = evaled.config;
  in {
    expr = lib.attrNames config.nodejs-package-lock-v3.pdefs.strip-ansi;
    expected = [
      "3.0.1"
      "4.0.0"
      "6.0.0"
    ];
  };

  test_nodejs_wrong_lockfile_version = let
    evaled = eval {
      imports = [
        dream2nix.modules.dream2nix.nodejs-package-lock-v3
      ];
      nodejs-package-lock-v3.packageLock = lib.mkForce {
        # Example content of lockfile
        # "lockfileVersion" = 1;
      };
    };
    config = evaled.config;
  in {
    expr = builtins.tryEval (config.nodejs-package-lock-v3.pdefs);
    expected =  {
      success = false;
      value = false;
    };
  };

}
