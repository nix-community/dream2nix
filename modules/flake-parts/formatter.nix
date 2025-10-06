{
  perSystem = {
    lib,
    pkgs,
    ...
  }: {
    formatter = let
      path = lib.makeBinPath [
        pkgs.alejandra
        pkgs.python3.pkgs.black
      ];
    in pkgs.writeScriptBin "format" ''
      export PATH="${path}"
      ${pkgs.treefmt}/bin/treefmt --clear-cache "$@"
    '';
  };
}
