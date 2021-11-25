{
  lib,
  fetchurl,

  utils,
  ...
}:
{

  inputs = [
    "pname"
    "version"
    "hash"
  ];

  versionField = "version";

  outputs = { pname, version, hash, ... }@inp:
    let
      b = builtins;
      # See https://github.com/rust-lang/crates.io-index/blob/master/config.json#L2
      url = "https://crates.io/api/v1/crates/${pname}/${version}/download";
    in
    {
      calcHash = algo: utils.hashFile algo (b.fetchurl {
        inherit url;
      });

      fetched = hash:
        fetchurl {
          inherit url;
          sha256 = hash;
          name = "download-${pname}-${version}";
        };
    };
}
