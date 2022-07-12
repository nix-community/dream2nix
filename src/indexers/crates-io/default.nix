{...}: {
  indexBin = {
    rustPlatform,
    runCommandLocal,
    openssl,
    pkg-config,
    zlib,
    curl,
    libssh2,
    libgit2,
    ...
  }: let
    package = rustPlatform.buildRustPackage {
      name = "indexer";

      src = ./indexer;

      cargoLock.lockFile = ./indexer/Cargo.lock;

      buildInputs = [openssl libgit2 libssh2 zlib curl];
      nativeBuildInputs = [pkg-config];

      doCheck = false;

      LIBSSH2_SYS_USE_PKG_CONFIG = 1;
    };
  in
    runCommandLocal package.name {} ''
      ln -sf ${package}/bin/indexer $out
    '';
}
