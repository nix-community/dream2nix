{
  # dream2nix deps
  dream2nixConfigFile,
  dream2nixWithExternals,
  utils,
  pkgs,
  ...
}:
utils.writePureShellScript
[pkgs.nix]
''
  nix ''${@:1:$#-1} --impure --expr "
    let
      nixpkgs = <nixpkgs>;
      l = (import \"\''${nixpkgs}/lib\") // builtins;
      dream2nix = import ${dream2nixWithExternals} {
        config = ''${dream2nixConfig:-"${dream2nixConfigFile}"};
      };
    in ''${@:$#}
  "
''
