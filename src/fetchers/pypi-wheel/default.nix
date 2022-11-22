{
  pkgs,
  utils,
  lib,
  ...
}: {
  inputs = ["filename"];

  versionField = "version";

  defaultUpdater = "pypiNewestReleaseVersion";

  outputs = {filename}: let
    parts = lib.splitString "-" filename;
    pname = builtins.elemAt parts 0;
    version = builtins.elemAt parts 1;
  in {
    fetched = hash:
      pkgs.runCommand
      "${pname}-pypi-url"
      {
        buildInputs = [
          pkgs.curl
          pkgs.cacert
          pkgs.jq
        ];
        outputHash = hash;
        outputHashAlgo = "sha256";
        outputHashMode = "flat";
        inherit filename pname version;
      }
      ''
        url=$(curl "https://pypi.org/pypi/$pname/json" | jq -r ".releases.\"$version\"[] | select(.filename == \"$filename\") | .url")
        curl $url --output $out
      '';
  };
}
