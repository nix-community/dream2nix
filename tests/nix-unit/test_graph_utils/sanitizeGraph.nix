{lib ? import <nixpkgs/lib>, ...}: let
  util = import ../../../lib/internal/graphUtils.nix {inherit lib;};
in {
  test_simple = {
    expr = util.sanitizeGraph {
      root = {
        name = "a";
        version = "1.0.0";
      };
      graph = {
        a."1.0.0" = {
          dependencies = {
            b.version = "1.0.0";
          };
          dev = true;
        };
        b."1.0.0" = {
          dependencies = {
            a.version = "1.0.0";
          };
          dev = true;
        };
      };
    };
    expected = [
      {
        isRoot = true;
        key = ["a" "1.0.0"];
        name = "a";
        version = "1.0.0";
      }
      {
        dev = true;
        key = ["b" "1.0.0"];
        name = "b";
        parent = {
          name = "a";
          version = "1.0.0";
        };
        version = "1.0.0";
      }
    ];
  };
  test_two_cycles = {
    expr = util.sanitizeGraph {
      root = {
        name = "a";
        version = "1.0.0";
      };
      graph = {
        a."1.0.0" = {
          dependencies = {
            c.version = "1.0.0";
          };
          dev = true;
        };
        b."1.0.0" = {
          dependencies = {
            c.version = "1.0.0";
          };
          dev = true;
        };
        c."1.0.0" = {
          dependencies = {
            d.version = "1.0.0";
          };
          dev = true;
        };
        d."1.0.0" = {
          dependencies = {
            a.version = "1.0.0";
            b.version = "1.0.0";
          };
          dev = true;
        };
      };
    };
    expected = [
      {
        isRoot = true;
        key = ["a" "1.0.0"];
        name = "a";
        version = "1.0.0";
      }
      {
        dev = true;
        key = ["c" "1.0.0"];
        name = "c";
        parent = {
          name = "a";
          version = "1.0.0";
        };
        version = "1.0.0";
      }
      {
        dev = true;
        key = ["d" "1.0.0"];
        name = "d";
        parent = {
          name = "c";
          version = "1.0.0";
        };
        version = "1.0.0";
      }
      {
        dev = true;
        key = ["b" "1.0.0"];
        name = "b";
        parent = {
          name = "d";
          version = "1.0.0";
        };
        version = "1.0.0";
      }
    ];
  };
}
