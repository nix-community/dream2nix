{
  fetchurl,
  python3,
  utils,
  ...
}: {
  inputs = ["pname" "version"];

  versionField = "version";

  defaultUpdater = "pypiNewestReleaseVersion";

  outputs = {
    pname,
    version,
    extension ? "tar.gz",
  } @ inp: let
    b = builtins;

    firstChar = builtins.substring 0 1 pname;
    url =
      "https://files.pythonhosted.org/packages/source/"
      + "${firstChar}/${pname}/${pname}-${version}.${extension}";
  in {
    calcHash = algo:
      utils.hashPath algo (
        b.fetchurl {inherit url;}
      );

    fetched = hash: let
      source =
        (fetchurl {
          inherit url;
          sha256 = hash;
        })
        .overrideAttrs (old: {
          outputHashMode = "recursive";
        });
    in
      utils.extractSource {
        inherit source;
      };
  };
}
