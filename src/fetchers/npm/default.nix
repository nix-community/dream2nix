{
  fetchurl,
  lib,
  python3,

  utils,
  ...
}:
{

  inputs = [
    "pname"
    "version"
  ];

  versionField = "version";

  # defaultUpdater = "";

  outputs = { pname, version, ... }@inp:
    let
      b = builtins;

      submodule = lib.last (lib.splitString "/" pname);
      url = "https://registry.npmjs.org/${pname}/-/${submodule}-${version}.tgz";
    in
    {

      calcHash = algo: utils.hashPath algo (
        b.fetchurl { inherit url; }
      );

      fetched = hash:
        (fetchurl {
          inherit url;
          sha256 = hash;
        }).overrideAttrs (old: {
          outputHashMode = "recursive";
        });
    };
}
