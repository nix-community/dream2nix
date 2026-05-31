{
  pkgs ? import <nixpkgs> {},
  lib ? import <nixpkgs/lib>,
  inputs ? {},
  dream2nix ? import ../../.. inputs,
}: let
  fixtures = import ../fixtures.nix {inherit dream2nix;};
  eval = module:
    (lib.evalModules {
      modules = [
        dream2nix.modules.dream2nix.WIP-groups
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
      groups.my-group = {
        packages.hello."1.0.0".module = _: fixtures.basic-derivation;
      };
    };
  in {
    expr = config.groups.my-group.packages.hello."1.0.0".public ? drvPath;
    expected = true;
  };

  test_groups_overrideAll = let
    config = eval {
      groups.my-group = {
        packages.hello."1.0.0".module = _: fixtures.basic-derivation;
      };
      overrideAll = {name = lib.mkForce "hello-mod";};
    };
  in {
    expr = "${config.groups.my-group.packages.hello."1.0.0".public.name}";
    expected = "hello-mod";
  };

  groups_overrides_global = let
    config = eval {
      groups.my-group = {
        packages.foo."1.0.0".module = _: fixtures.basic-derivation;
        packages.bar."1.0.0".module = _: fixtures.basic-derivation;
        overrides = {foo = {version = lib.mkForce "2.0.0";};};
      };
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
      groups.my-group = {
        packages.foo."1.0.0".module = _: fixtures.basic-derivation;
        packages.bar."1.0.0".module = _: fixtures.basic-derivation;
        overrides = {foo = {version = lib.mkForce "2.0.0";};};
      };
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
      groups.my-group = {
        packages.foo."1.0.0".module = _: fixtures.basic-derivation;
        packages.bar."1.0.0".module = _: fixtures.basic-derivation;
        overrides = {foo = {version = lib.mkForce "3.0.0";};};
      };
      overrides = {foo = {version = lib.mkForce "2.0.0";};};
    };
  in {
    expr = "${config.groups.my-group.packages.foo."1.0.0".public.version}";
    expectedError.msg = ''The option `groups.my-group.packages.foo."1.0.0".evaluated.version' has conflicting definition values:'';
  };
}
