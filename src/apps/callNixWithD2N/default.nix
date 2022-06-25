{
  # dream2nix deps
  utils,
  dream2nixWithExternals,
  # nixpkgs deps
  nix,
  ...
} @ args:
utils.writePureShellScriptBin
"callNixWithD2N"
[nix]
''
  cd $WORKDIR
  nix ''${@:1:$#-1} --impure --expr "
    let
      nixpkgs = <nixpkgs>;
      l = (import \"\''${nixpkgs}/lib\") // builtins;
      dream2nix = import ${dream2nixWithExternals} {
        config = ''${dream2nixConfig:-"{}"};
      };
    in ''${@:$#}
  "
''
