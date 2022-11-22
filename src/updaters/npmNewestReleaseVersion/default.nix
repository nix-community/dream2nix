{
  pkgs,
  utils,
  ...
}: {pname, ...}:
# api docs: https://github.com/npm/registry/blob/master/docs/REGISTRY-API.md#get
utils.writePureShellScript (with pkgs; [curl jq]) ''
  curl -s https://registry.npmjs.com/${pname} | jq -r '."dist-tags".latest'
''
