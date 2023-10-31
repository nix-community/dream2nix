{
  self,
  lib,
  inputs,
  ...
}: {
  perSystem = {
    config,
    self',
    inputs',
    pkgs,
    ...
  }: {
    checks = {
      pre-commit-check = inputs.pre-commit-hooks.lib.${pkgs.system}.run {
        src = self;
        hooks = {
          treefmt = {
            enable = true;
            name = "treefmt";
            pass_filenames = false;
            entry = toString (pkgs.writeScript "treefmt" ''
              #!${pkgs.bash}/bin/bash
              export PATH="$PATH:${lib.makeBinPath [
                pkgs.alejandra
                pkgs.python3.pkgs.black
              ]}"
              ${pkgs.treefmt}/bin/treefmt --clear-cache --fail-on-change
            '');
          };
        };
      };
    };
  };
}
