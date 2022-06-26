{
  # dream2nix deps
  dream2nixWithExternals,
  # nixpkgs deps
  writers,
  nix,
  pkgs,
  ...
} @ args:
writers.writeBash
"writeFlakeD2N"
''
  set -e

  writeTo=''${1:?"error: pass a location to write the flake to"}

  echo "{
    outputs = inp:
      let
        b = builtins;
        system = b.currentSystem;
        pkgs = import ${pkgs.path} {inherit system;};
        d2n = import ${dream2nixWithExternals} {
          inherit pkgs;
          config = ''${dream2nixConfig:-"{}"};
        };
        src = d2n.fetchers.fetchSource {
          source = b.fromJSON (b.readFile \"''${flakeSrcInfoPath:?"error: set source info path"}\");
        };
      in
        b.mapAttrs
        (k: v: {\''${system} = v;})
        (d2n.makeOutputs {source = src;})
      ;
  }
  " > $writeTo
''
