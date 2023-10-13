# copied from poetry2nix
# LICENSE: https://github.com/nix-community/poetry2nix/blob/master/LICENSE
{
  lib,
  curl,
  jq,
  stdenvNoCC,
}: let
  # Predict URL from the PyPI index.
  # Args:
  #   pname: package name
  #   file: filename including extension
  #   hash: SRI hash
  #   kind: Language implementation and version tag
  predictURLFromPypi = lib.makeOverridable (
    {
      pname,
      file,
      hash,
      kind,
    }: "https://files.pythonhosted.org/packages/${kind}/${lib.toLower (builtins.substring 0 1 file)}/${pname}/${file}"
  );

  # Fetch from the PyPI index.
  # At first we try to fetch the predicated URL but if that fails we
  # will use the Pypi API to determine the correct URL.
  # Args:
  #   pname: package name
  #   file: filename including extension
  #   version: the version string of the dependency
  #   hash: SRI hash
  #   kind: Language implementation and version tag
  fetchFromPypi = lib.makeOverridable (
    {
      pname,
      file,
      version,
      hash,
      kind,
      curlOpts ? "",
    }: let
      predictedURL = predictURLFromPypi {inherit pname file hash kind;};
    in (stdenvNoCC.mkDerivation {
      name = file;
      nativeBuildInputs = [
        curl
        jq
      ];
      isWheel = lib.strings.hasSuffix "whl" file;
      system = "builtin";

      preferLocalBuild = true;
      impureEnvVars =
        lib.fetchers.proxyImpureEnvVars
        ++ [
          "NIX_CURL_FLAGS"
        ];

      inherit pname file version curlOpts predictedURL;

      builder = ./fetch-from-pypi.sh;

      outputHashMode = "flat";
      outputHashAlgo = "sha256";
      outputHash = hash;

      passthru = {
        urls = [predictedURL]; # retain compatibility with nixpkgs' fetchurl
      };
    })
  );
in
  fetchFromPypi
