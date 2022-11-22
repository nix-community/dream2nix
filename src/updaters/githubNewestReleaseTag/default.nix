{
  pkgs,
  utils,
  ...
}: {
  owner,
  repo,
  ...
}:
utils.writePureShellScript (with pkgs; [curl jq]) ''
  curl -s "https://api.github.com/repos/${owner}/${repo}/releases?per_page=1" | jq -r '.[0].tag_name'
''
