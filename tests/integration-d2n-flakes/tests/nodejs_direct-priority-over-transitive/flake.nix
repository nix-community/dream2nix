# test: node.js direct dep priority over transitive dep
#
# Detecting regressions for #221.
#
# Node.js builder was linking the wrong version of a binary,
# if there was another dependency transitivelly depending on another version,
# this one would be resolved instead of the direct dependency.
#
# Dependencies: svgo@2, cssnano@4 (cssnano@4 -> svgo@1)
#
# 1. Dream2Nix normal build.
# 2. Get version of svgo in node.js path. (npm run get-version = svgo --version)
# 3. Check if this is the same version as the direct dependency.
#
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
    autoProjects = true;
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
