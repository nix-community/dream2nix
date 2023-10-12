{lib ? import <nixpkgs/lib>, ...}: let
  util = import ../../../lib/internal/graphUtils.nix {inherit lib;};
in {
  test_simple = {
    expr = util.sanitizeGraph {
      graph = {
        a = [
          "b"
        ];
        b = [
          "a"
        ];
      };
      roots = ["a"];
    };
    expected = {
      # __virtRoot = ["a"];
      a = ["b"];
      b = [];
    };
  };
  test_two_cycles = {
    expr = util.sanitizeGraph {
      graph = {
        a = [
          "c"
        ];
        b = [
          "c"
        ];
        c = [
          "d"
        ];
        d = [
          "a"
          "b"
        ];
      };
      roots = ["a" "b"];
    };
    expected = {
      # __virtRoot = ["a" "b"];
      a = ["c"];
      b = [];
      c = ["d"];
      d = [];
    };
  };

  # Compat conversion methods
  ###################################################

  # convert into normalized format
  test_convert_from_dep_graph_simple = {
    expr = util.fromDependencyGraph {
      "@org/a"."1.0.0" = [
        {
          name = "b";
          version = "1.0.0";
        }
      ];
      "@scope/b"."1.0.0" = [
        {
          name = "a";
          version = "1.0.0";
        }
      ];
    };
    expected = {
      "@org/a/1.0.0" = ["b/1.0.0"];
      "@scope/b/1.0.0" = ["a/1.0.0"];
    };
  };
  test_convert_from_dep_graph_conflicts = {
    expr = util.fromDependencyGraph {
      "a"."1.0.0" = [
        {
          name = "@org/a";
          version = "1.1.0";
        }
      ];
      "@org/a"."1.1.0" = [
        {
          name = "a";
          version = "1.0.0";
        }
      ];
    };
    expected = {
      "a/1.0.0" = ["@org/a/1.1.0"];
      "@org/a/1.1.0" = ["a/1.0.0"];
    };
  };

  # convert back from normalized graph format
  test_convert_to_dep_graph_simple = {
    expr = util.toDependencyGraph {
      "a/1" = ["c/1"];
      "b/1" = [];
      "c/1" = ["d/1"];
      "d/1" = [];
    };
    expected = {
      a = {
        "1" = [
          {
            name = "c";
            version = "1";
          }
        ];
      };
      b = {"1" = [];};
      c = {
        "1" = [
          {
            name = "d";
            version = "1";
          }
        ];
      };
      d = {"1" = [];};
    };
  };

  test_convert_to_dep_graph_unknown_versions = {
    expr = util.toDependencyGraph {
      "a" = ["c"];
      b = [];
      c = ["d"];
      d = [];
    };
    expected = {
      a.unknown = [
        {
          name = "c";
          version = "unknown";
        }
      ];

      b.unknown = [];
      c.unknown = [
        {
          name = "d";
          version = "unknown";
        }
      ];
      d.unknown = [];
    };
  };

  test_simple_legacy = {
    expr = util.toDependencyGraph (util.sanitizeGraph {
      graph = util.fromDependencyGraph {
        a.v1 = [
          {
            name = "b";
            version = "v1";
          }
        ];
        b.v1 = [
          {
            name = "a";
            version = "v1";
          }
        ];
      };
      roots = [
        "a/v1"
      ];
    });
    expected = {
      a.v1 = [
        {
          name = "b";
          version = "v1";
        }
      ];
      b.v1 = [];
    };
  };
}
