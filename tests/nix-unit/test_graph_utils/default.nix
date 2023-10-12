{
  lib ? import <nixpkgs/lib>,
  ...
}: let
  sanitizeGraphTests = import ./sanitizeGraph.nix {inherit lib;};
in {
 inherit sanitizeGraphTests; 
}
