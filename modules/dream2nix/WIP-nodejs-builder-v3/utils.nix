  {lib,
}: let
  l = lib // builtins;
  # cfg = config.WIP-nodejs-builder-v3;


  nodejsLockUtils = import ../../../lib/internal/nodejsLockUtils.nix {inherit lib;};
  graphUtils = import ../../../lib/internal/graphUtils.nix {inherit lib;};


  isLink = plent: plent ? link && plent.link;
  
  getInfo = path: plent: {
    initialPath = path;
    initialState =
      if
        isLink plent
        ||
        /*
        IsRoot
        */
        path == ""
      then "source"
      else "dist";

    pdefs' = {
      graph,
      root ? {
        name = plent.name or "nixpkgs-docs-example";
        version = plent.version;
      },
      opt ? {},
    }:
      graphUtils.sanitizeGraph {
        inherit root graph;
        pred = (
          e:
            l.foldlAttrs (
              res: name: value:
                if res == false
                then false
                else value == e.${name}
            )
            true
            opt
        );
      };
  };
in {
  inherit getInfo;
}
