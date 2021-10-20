{
  fetchurl,
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

      calcHash = algo: utils.hashPath algo (
        let
          firstChar = builtins.substring 0 1 pname;
          result = b.fetchurl {
            url =
              "https://files.pythonhosted.org/packages/source/"
              + "${firstChar}/${pname}/${pname}-${version}.${extension}";
          };
        in
          result
      
      );

      fetched = hash:
        let
          firstChar = builtins.substring 0 1 pname;
          result = (fetchurl {
            url =
              "https://files.pythonhosted.org/packages/source/"
              + "${firstChar}/${pname}/${pname}-${version}.${extension}";
            sha256 = hash;
          }).overrideAttrs (old: {
            outputHashMode = "recursive";
          });
        in
          result;
    };
}
