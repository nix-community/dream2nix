{lib ? import <nixpkgs/lib>, ...}: let
  utils = import ../../../lib/internal/graphUtils.nix {inherit lib;};
in {
  test_simple = let
    graph = {
      "a"."1" = {
        dist = "<Dist Derivation>";
        dependencies = {};
        dev = false;
        bins = {
        };
        info = {
          initialState = "dist";
          allPaths = {
            "node_modules/a" = true;
          };
        };
      };
    };
    sanitizedGraph = utils.sanitizeGraph {
      inherit graph;
      root = {
        name = "a";
        version = "1";
      };
    };

    fileSystem = utils.getFileSystem graph sanitizedGraph;
  in {
    expr = fileSystem;
    expected = {
      "node_modules/a" = {
        bins = {};
        source = "<Dist Derivation>";
      };
    };
  };
  # Currently only "dist" packages
  # can be used to populate node_modules
  test_only_dist = let
    graph = {
      "a"."1" = {
        dist = "<Source A Derivation>";
        dependencies = {
          b.version = "1";
        };
        dev = false;
        bins = {
        };
        info = {
          initialState = "source";
          allPaths = {
            "" = true;
          };
        };
      };
      "b"."1" = {
        dist = "<B Derivation>";
        dependencies = {};
        dev = false;
        bins = {
        };
        info = {
          initialState = "dist";
          allPaths = {
            "node_modules/b" = true;
          };
        };
      };
    };

    sanitizedGraph = utils.sanitizeGraph {
      inherit graph;
      root = {
        name = "a";
        version = "1";
      };
    };

    fileSystem = utils.getFileSystem graph sanitizedGraph;
  in {
    expr = fileSystem;
    expected = {
      "node_modules/b" = {
        bins = {};
        source = "<B Derivation>";
      };
    };
  };

  test_cyclic_dependency = let
    graph = {
      "a"."1" = {
        dist = "<A Derivation>";
        dependencies = {
          b.version = "1";
        };
        dev = false;
        bins = {};
        info = {
          initialState = "dist";
          allPaths = {
            "node_modules/a" = true;
          };
        };
      };
      "b"."1" = {
        dist = "<B Derivation>";
        dependencies = {
          a.version = "1";
        };
        dev = false;
        bins = {};
        info = {
          initialState = "dist";
          allPaths = {
            "node_modules/b" = true;
          };
        };
      };
    };
    sanitizedGraph = utils.sanitizeGraph {
      inherit graph;
      root = {
        name = "a";
        version = "1";
      };
    };

    fileSystem = utils.getFileSystem graph sanitizedGraph;
  in {
    expr = fileSystem;
    expected = {
      "node_modules/a" = {
        bins = {};
        source = "<A Derivation>";
      };
      "node_modules/b" = {
        bins = {};
        source = "<B Derivation>";
      };
    };
  };

  test_bin_conflict = let
    graph = {
      "a"."1" = {
        dist = "<A Derivation>";
        dependencies = {
          b.version = "1";
          c.version = "1";
        };
        dev = false;
        bins = {
        };
        info = {
          initialState = "dist";
          allPaths = {
            "node_modules/a" = true;
          };
        };
      };
      "b"."1" = {
        dist = "<B Derivation>";
        dependencies = {
          c.version = "2";
          d.version = "1";
        };
        dev = false;
        bins = {
        };
        info = {
          initialState = "dist";
          allPaths = {
            "node_modules/b" = true;
          };
        };
      };
      "d"."1" = {
        dist = "<D Derivation>";
        dependencies = {
          c.version = "2";
        };
        dev = false;
        bins = {
        };
        info = {
          initialState = "dist";
          allPaths = {
            "node_modules/d" = true;
          };
        };
      };
      "c"."1" = {
        dist = "<C1 Derivation>";
        dependencies = {
        };
        dev = false;
        bins = {
          c-cli = "cli.js";
        };
        info = {
          initialState = "dist";
          allPaths = {
            "node_modules/c" = true;
          };
        };
      };
      "c"."2" = {
        dist = "<C2 Derivation>";
        dependencies = {
        };
        dev = false;
        bins = {
          c-cli = "cli.js";
        };
        info = {
          initialState = "dist";
          allPaths = {
            "node_modules/b/node_modules/c" = true;
            "node_modules/d/node_modules/c" = true;
          };
        };
      };
    };
    sanitizedGraph = utils.sanitizeGraph {
      inherit graph;
      root = {
        name = "a";
        version = "1";
      };
    };

    fileSystem = utils.getFileSystem graph sanitizedGraph;
  in {
    expr = fileSystem;
    expected = {
      "node_modules/a" = {
        bins = {};
        source = "<A Derivation>";
      };
      "node_modules/b" = {
        bins = {};
        source = "<B Derivation>";
      };
      "node_modules/b/node_modules/c" = {
        bins = {"node_modules/b/node_modules/.bin/c-cli" = "node_modules/b/node_modules/c/cli.js";};
        source = "<C2 Derivation>";
      };
      "node_modules/c" = {
        bins = {"node_modules/.bin/c-cli" = "node_modules/c/cli.js";};
        source = "<C1 Derivation>";
      };
      "node_modules/d" = {
        bins = {};
        source = "<D Derivation>";
      };
      "node_modules/d/node_modules/c" = {
        bins = {"node_modules/d/node_modules/.bin/c-cli" = "node_modules/d/node_modules/c/cli.js";};
        source = "<C2 Derivation>";
      };
    };
  };
}
