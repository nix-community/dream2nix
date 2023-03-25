# ml/json-ld depends on ml/iri, and ml/iri uses the (deprecated)
# `target-dir` attribute, which appears to cause a mismatch between
# dream2nix and composer behavior and makes the build fail.
#
# Since target-dir is deprecated and will be removed in a future
# version of ml/iri anyway, a neat solution is to override the
# package and add a prePatch phase that drops the attribute,
# fixing the build:
{
  inputs.dream2nix.url = "github:nix-community/dream2nix";
  outputs = inp:
    inp.dream2nix.lib.makeFlakeOutputs {
      systems = ["x86_64-linux"];
      config.projectRoot = ./.;
      source = ./.;
      projects = ./projects.toml;
      packageOverrides = {
        "^ml.iri.*".updated.overrideAttrs = old: {
          prePatch = ''
            cat composer.json | grep -v target-dir | sponge composer.json
          '';
        };
      };
    };
}
