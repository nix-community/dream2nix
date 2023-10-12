{
  lib ? import <nixpkgs/lib>,
  ...
}: let
  findCyclesTests = import ./findCycles.nix {inherit lib;};
  sanitizeGraphTests = import ./sanitizeGraph.nix {inherit lib;};
in {
 inherit findCyclesTests sanitizeGraphTests; 
}