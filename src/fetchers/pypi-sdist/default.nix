{
  python3,

  utils,
  # config
  allowBuiltinFetchers,
  ...
}:
{

  inputs = [
    "pname"
    "version"
  ];

  versionField = "version";

  defaultUpdater = "pypiNewestReleaseVersion";

  outputs = { pname, version, extension ? "tar.gz", ... }@inp:
    let
      b = builtins;
    in
    {

      calcHash = algo: utils.hashPath algo (b.fetchurl {
        url = "https://files.pythonhosted.org/packages/${builtins.substring 0 1 pname}/${pname}/${pname}-${version}.${extension}";
      });

      fetched = hash:
        python3.pkgs.fetchPypi {
          inherit pname version extension hash;
        };
    };
}
