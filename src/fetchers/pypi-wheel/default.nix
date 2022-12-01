{
  pkgs,
  utils,
  lib,
  ...
}: {
  inputs = ["filename"];

  versionField = "version";

  defaultUpdater = "pypiNewestReleaseVersion";

  outputs = {
    filename,
    pname,
    version,
  }: {
    fetched = hash:
      pkgs.runCommand
      filename
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
