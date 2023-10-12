{lib ? import <nixpkgs/lib>, ...}: let
  utils = import ../../../lib/internal/graphUtils.nix {inherit lib;};
in {
  test_simple = {
    expr = utils.findCycles {
      dependencyGraph = {
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
      roots = {
        a = "v1";
      };
    };
    expected = {
      b.v1 = [
        {
          name = "a";
          version = "v1";
        }
      ];
    };
  };

  test_cycle_length_3 = {
    expr = utils.findCycles {
      dependencyGraph = {
        a.v1 = [
          {
            name = "b";
            version = "v1";
          }
        ];
        b.v1 = [
          {
            name = "c";
            version = "v1";
          }
        ];
        c.v1 = [
          {
            name = "a";
            version = "v1";
          }
        ];
      };
      roots = {
        a = "v1";
      };
    };
    expected = {
      c.v1 = [
        {
          name = "a";
          version = "v1";
        }
      ];
    };
  };

  test_two_roots_both_chosen = {
    expr = utils.findCycles {
      dependencyGraph = {
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
        c.v1 = [
          {
            name = "d";
            version = "v1";
          }
        ];
        d.v1 = [
          {
            name = "c";
            version = "v1";
          }
        ];
      };
      roots = {
        a = "v1";
        c = "v1";
      };
    };
    expected = {
      b.v1 = [
        {
          name = "a";
          version = "v1";
        }
      ];
      d.v1 = [
        {
          name = "c";
          version = "v1";
        }
      ];
    };
  };

  test_two_roots_one_chosen = {
    expr = utils.findCycles {
      dependencyGraph = {
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
        c.v1 = [
          {
            name = "d";
            version = "v1";
          }
        ];
        d.v1 = [
          {
            name = "c";
            version = "v1";
          }
        ];
      };
      roots = {
        a = "v1";
      };
    };
    expected = {
      b.v1 = [
        {
          name = "a";
          version = "v1";
        }
      ];
    };
  };

  test_c_visited_twice_no_cycle = {
    expr = utils.findCycles {
      dependencyGraph = {
        a.v1 = [
          {
            name = "c";
            version = "v1";
          }
        ];
        b.v1 = [
          {
            name = "c";
            version = "v1";
          }
        ];
        c.v1 = [];
      };
      roots = {
        a = "v1";
        b = "v1";
      };
    };
    expected = {};
  };

  test_two_cycles_one_root = {
    expr = utils.findCycles {
      dependencyGraph = {
        a.v1 = [
          {
            name = "c";
            version = "v1";
          }
        ];
        b.v1 = [
          {
            name = "c";
            version = "v1";
          }
        ];
        c.v1 = [
          {
            name = "d";
            version = "v1";
          }
        ];
        d.v1 = [
          {
            name = "a";
            version = "v1";
          }
          {
            name = "b";
            version = "v1";
          }
        ];
      };
      roots = {
        a = "v1";
      };
    };
    expected = {
      d.v1 = [
        {
          name = "a";
          version = "v1";
        }
      ];
      b.v1 = [
        {
          name = "c";
          version = "v1";
        }
      ];
    };
  };

  # TODO: fix the implementation to remove furthest edges from the root only
  # test_two_cycles_two_roots = {
  #   expr = findCycles {
  #     dependencyGraph = {
  #       a.v1 = [
  #         {name = "c"; version = "v1";}
  #       ];
  #       b.v1 = [
  #         {name = "c"; version = "v1";}
  #       ];
  #       c.v1 = [
  #         {name = "d"; version = "v1";}
  #       ];
  #       d.v1 = [
  #         {name = "a"; version = "v1";}
  #         {name = "b"; version = "v1";}
  #       ];
  #     };
  #     roots = {
  #       a = "v1";
  #       b = "v1";
  #     };
  #   };
  #   expected = {
  #     d.v1 = [
  #       {name = "a"; version = "v1";}
  #       {name = "b"; version = "v1";}
  #     ];
  #   };
  # };
}
