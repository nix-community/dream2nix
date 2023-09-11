{
  # pkgs ? import <nixpkgs> {},
  lib ? import <nixpkgs/lib>,
  nodejsLockUtils ? import ../../../lib/internal/nodejsLockUtils.nix {inherit lib;},
}: {
  # test the path strip function
  test_nodejsLockUtils_stripPath_simple = let
    nextPath = nodejsLockUtils.stripPath "node_modules/@org/lib/node_modules/bar";
  in {
    expr = nextPath;
    expected = "node_modules/@org/lib";
  };

  test_nodejsLockUtils_stripPath_root = let
    nextPath = nodejsLockUtils.stripPath "node_modules/bar";
  in {
    expr = nextPath;
    # The root
    expected = "";
  };

  test_nodejsLockUtils_stripPath_empty = let
    nextPath = nodejsLockUtils.stripPath "";
  in {
    expr = nextPath;
    expected = "";
  };

  test_nodejsLockUtils_stripPath_complex = let
    nextPath = nodejsLockUtils.stripPath "node_modules/@org/lib/node_modules/bar/node_modules/foo";
  in {
    expr = nextPath;
    expected = "node_modules/@org/lib/node_modules/bar";
  };

  # test the resolve function
  test_nodejsLockUtils_findEntry_argparse = let
    plock = builtins.fromJSON (builtins.readFile ./package-lock.json);
    path = nodejsLockUtils.findEntry plock "" "argparse";
  in {
    expr = path;
    expected = "node_modules/argparse";
  };

  test_nodejsLockUtils_findEntry_notFound = let
    plock = builtins.fromJSON (builtins.readFile ./package-lock.json);
    path = builtins.tryEval (nodejsLockUtils.findEntry plock "" "foo");
  in {
    expr = path;
    expected = {
      success = false;
      value = false;
    };
  };

  test_nodejsLockUtils_findEntry_deepNested_kitten = let
    plock = builtins.fromJSON (builtins.readFile ./package-lock.json);
    path =
      nodejsLockUtils.findEntry plock
      "node_modules/@org/nested/node_modules/foo"
      "kitten";
  in {
    expr = path;
    expected = "node_modules/@org/nested/node_modules/kitten";
  };

  test_nodejsLockUtils_findEntry_hoisted = let
    plock = builtins.fromJSON (builtins.readFile ./package-lock.json);
    path =
      nodejsLockUtils.findEntry plock
      "node_modules/argparse"
      "underscore";
  in {
    expr = path;
    expected = "node_modules/underscore";
  };
  
}
