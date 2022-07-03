{
  # dream2nix deps
  configFile,
  dream2nixWithExternals,
  utils,
  # nixpkgs deps
  nix,
  ...
} @ args:
utils.writePureShellScript
[nix]
''
  cd $WORKDIR
  nix ''${@:1:$#-1} --impure --expr "
    let
      nixpkgs = <nixpkgs>;
      l = (import \"\''${nixpkgs}/lib\") // builtins;
      dream2nix = import ${dream2nixWithExternals} {
        config = ''${dream2nixConfig:-"${configFile}"};
      };
    in ''${@:$#}
  "
''
