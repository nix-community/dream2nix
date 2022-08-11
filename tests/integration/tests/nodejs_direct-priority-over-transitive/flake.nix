{
  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";
  };

  outputs = {
    self,
    dream2nix,
  }: (dream2nix.lib.makeFlakeOutputs {
    systems = ["x86_64-linux"];
    config.projectRoot = ./.;
    source = ./.;
    packageOverrides = {
      test = {
        "check-linked-bin-version" = {
          postInstall = ''
            npm run get-version
            VERSION=$(cat VERSION)
            echo "$VERSION"

            if [ "$VERSION" = "2.8.0" ]; then
              echo "correct version installed - direct dependency"
            else
              echo "wrong version installed - transitive dependency"
              exit 1
            fi
          '';
        };
      };
    };
  });
}
