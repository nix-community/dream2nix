{
  pkgs,
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
  }: let
    b = builtins;

    firstChar = builtins.substring 0 1 pname;
    url =
      "https://files.pythonhosted.org/packages/source/"
      + "${firstChar}/${pname}/${pname}-${version}.${extension}";
  in {
    fetched = hash: let
      source = pkgs.fetchurl {
        inherit url;
        sha256 = hash;
      };
    in
      utils.extractSource {
        inherit source;
      };
  };
}
