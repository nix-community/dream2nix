{
  pkgs,
  utils,
  ...
}: {pname, ...}:
utils.writePureShellScript (with pkgs; [curl jq]) ''
  curl -s https://pypi.org/pypi/${pname}/json | jq -r '.info.version'
''
