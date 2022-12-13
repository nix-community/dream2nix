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

  # Use $1 as source if set. Otherwise default to ./.
  export source=$(realpath ''${1:-.})

  ${apps.callNixWithD2N} eval --json \
    "dream2nix.functions.discoverers.discoverProjects2 {source = builtins.getEnv \"source\";}" \
    | yq --toml-output \
    | (cat ${./template.toml} && echo "" && cat)
''
