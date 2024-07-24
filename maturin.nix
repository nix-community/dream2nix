# maturin in nixpkgs only contains the binary, as nixpkgs itself
# uses its own maturin-build-hook. We do need upstreams python
# import hook as well for pep517 builds.
{
  python3,
  maturin,
  rustPlatform,
  cargo,
  rustc,
  pkg-config,
  openssl,
}:
python3.pkgs.buildPythonPackage rec {
  inherit (maturin) pname version src;

  pythonImportsCheck = [
    "maturin"
  ];

  cargoDeps = rustPlatform.fetchCargoTarball {
    inherit src;
    name = "${pname}-${version}";
    hash = maturin.cargoHash;
  };

  nativeBuildInputs = [
    cargo
    rustPlatform.cargoSetupHook
    rustc
    pkg-config
  ];

  buildInputs = [
    openssl.dev
  ];

  propagatedBuildInputs = [
    python3.pkgs.setuptools-rust
  ];
}
