# custom app to run our test suite
{
  self,
  lib,
  inputs,
  ...
}: {
  imports = [
    ./writers.nix
  ];
  perSystem = {
    config,
    self',
    inputs',
    pkgs,
    system,
    ...
  }: let
    python = pkgs.python3.withPackages (p: [
      p.pytest
      p.pytest-timeout
      p.pexpect
    ]);
    script =
      config.writers.writePureShellScriptBin "test-runner"
      []
      ''
        ${python}/bin/python -m pytest $@
      '';
  in {
    apps.test = {
      type = "app";
      program = "${script}/bin/test-runner";
    };
  };
}
