# test: yarn-lock evaluation with @git+ in versions
#
# Detecting regressions of #275.
#
# Evaluation of a package.json and a yarn.lock with special cases for
# versions would cause mismatches between the two:
# ''error: attribute '*' missing'
#
# 1. package.json has a dependency with a version starting with "@git+"
# 2. yarn resolves it in its yarn.lock file to the proper version and reference
# 3. the two are either not parsed correctly or mismatched on evaluation
#
{
  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";
  };

  outputs = {
    self,
    dream2nix,
  }:
    dream2nix.lib.makeFlakeOutputs {
      systems = ["x86_64-linux"];
      config.projectRoot = ./.;
      packageOverrides = {};
      source = ./.;
    };
}
