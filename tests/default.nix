{
  inputs,
  self,
  ...
}: {
  perSystem = {
    config,
    pkgs,
    system,
    ...
  }: let
    b = builtins;

    callTests = f:
      pkgs.callPackage f {
        inherit self;
        framework = config.d2n;
      };
  in {
    apps = {
      tests-unit.type = "app";
      tests-unit.program =
        b.toString
        (callTests ./unit);

      tests-integration.type = "app";
      tests-integration.program =
        b.toString
        (callTests ./integration);

      tests-integration-d2n-flakes.type = "app";
      tests-integration-d2n-flakes.program =
        b.toString
        (callTests ./integration-d2n-flakes);

      tests-examples.type = "app";
      tests-examples.program =
        b.toString
        (callTests ./examples);

      tests-all.type = "app";
      tests-all.program =
        b.toString
        (config.d2n.utils.writePureShellScript
          [
            inputs.alejandra.defaultPackage.${system}
            pkgs.coreutils
            pkgs.gitMinimal
            pkgs.nix
          ]
          ''
            echo "check for correct formatting"
            WORKDIR=$(realpath ./.)
            cd $TMPDIR
            cp -r $WORKDIR ./repo
            cd ./repo
            ${config.apps.format.program} --fail-on-change
            cd -

            echo "running unit tests"
            ${config.apps.tests-unit.program}

            echo "running integration tests"
            ${config.apps.tests-integration.program}

            echo "checking flakes under ./examples"
            ${config.apps.tests-examples.program}

            echo "running nix flake check"
            cd $WORKDIR
            nix flake show >/dev/null
            nix flake check
          '');
    };
  };
}
