{
  # dream2nix deps
  dream2nixWithExternals,
  # nixpkgs deps
  writers,
  nix,
  ...
} @ args:
writers.writeBash
"callNixWithD2N"
''
  ${nix}/bin/nix ''${@:1:$#-1} --impure --expr "
    let
      nixpkgs = <nixpkgs>;
      l = (import \"\''${nixpkgs}/lib\") // builtins;
      dream2nix = import ${dream2nixWithExternals} {
        config = ''${dream2nixConfig:-"{}"};
      };
    in ''${@:$#}
  "
''
