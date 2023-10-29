{
  pkgs ? import <nixpkgs> {},
  lib ? import <nixpkgs/lib>,
  dream2nix ? (import (../../../modules + "/flake.nix")).outputs {},
}: let
  fixtures = import ../fixtures.nix {inherit dream2nix;};
  eval = module:
    (lib.evalModules {
      modules = [
        dream2nix.modules.dream2nix.groups
        module
      ];
      specialArgs = {
        inherit dream2nix;
        packageSets.nixpkgs = pkgs;
      };
    })
    .config;
in {
  test_groups_simple = let
    config = eval {
      groups.my-group.packages.hello."1.0.0".module = {...}: fixtures.basic-derivation;
    };
  in {
    expr = config.groups.my-group.packages.hello."1.0.0".public ? drvPath;
    expected = true;
  };

  test_groups_commonModule = let
    config = eval {
      groups.my-group.packages.hello."1.0.0".module = {...}: fixtures.basic-derivation;
      commonModule = {name = lib.mkForce "hello-mod";};
    };
  in {
    expr = "${config.groups.my-group.packages.hello."1.0.0".public.name}";
    expected = "hello-mod";
  };

  groups_overrides_global = let
    config = eval {
      groups.my-group.packages.foo."1.0.0".module = {...}: fixtures.basic-derivation;
      groups.my-group.packages.bar."1.0.0".module = {...}: fixtures.basic-derivation;
      overrides = {foo = {version = lib.mkForce "2.0.0";};};
    };
  in {
    test_foo_changed = {
      expr = "${config.groups.my-group.packages.foo."1.0.0".public.version}";
      expected = "2.0.0";
    };
    test_bar_unchanged = {
      expr = "${config.groups.my-group.packages.bar."1.0.0".public.version}";
      expected = "1.0.0";
    };
  };

  groups_overrides_local = let
    config = eval {
      groups.my-group.packages.foo."1.0.0".module = {...}: fixtures.basic-derivation;
      groups.my-group.packages.bar."1.0.0".module = {...}: fixtures.basic-derivation;
      groups.my-group.overrides = {foo = {version = lib.mkForce "2.0.0";};};
    };
  in {
    test_foo_changed = {
      expr = "${config.groups.my-group.packages.foo."1.0.0".public.version}";
      expected = "2.0.0";
    };
    test_bar_unchanged = {
      expr = "${config.groups.my-group.packages.bar."1.0.0".public.version}";
      expected = "1.0.0";
    };
  };

  test_groups_overrides_collision = let
    config = eval {
      groups.my-group.packages.foo."1.0.0".module = {...}: fixtures.basic-derivation;
      groups.my-group.packages.bar."1.0.0".module = {...}: fixtures.basic-derivation;
      overrides = {foo = {version = lib.mkForce "2.0.0";};};
      groups.my-group.overrides = {foo = {version = lib.mkForce "3.0.0";};};
    };
  in {
    expr = "${config.groups.my-group.packages.foo."1.0.0".public.version}";
    expectedError.msg = ''The option `groups.my-group.packages.foo."1.0.0".evaluated.version' has conflicting definition values:'';
  };
}
