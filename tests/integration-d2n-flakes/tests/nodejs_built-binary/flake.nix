# test: node.js built binary
#
# Detecting regressions of #235.
#
# Node.js builder was crashing if a binary defined in package.json
# bin section refers to a file that does not exist before the build step.
#
# 1. "package.json".bin.main = "./main.js"
# 2. `main.js` does not exist, but is created during the build
# 3. the default build script "package.json".scripts.build creates `main.js`
#    during the buildPhase
# 4. the binary is linked to the bin directory in the installPhase
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
  });
}
