{
  pkgs,
  utils,
  apps,
  ...
}:
utils.writePureShellScriptBin
"detect-projects"
(with pkgs; [
  coreutils
  yq
])
''
  set -e

  export source=$(realpath .)

  ${apps.callNixWithD2N} eval --json \
    "dream2nix.framework.functions.discoverers.discoverProjects2 {source = builtins.getEnv \"source\";}" \
    | yq --toml-output
''
