{...}: {
  indexBin = {
    initDream2nix,
    runCommandNoCC,
    openssl,
    pkg-config,
    zlib,
    curl,
    libssh2,
    libgit2,
    ...
  }: let
    dream2nixInterface = initDream2nix {
      config.projectRoot = ./indexer;
      config.disableIfdWarning = true;
    };
    package =
      (dream2nixInterface.makeOutputs {
        source = ./indexer;
        settings = [
          {
            builder = "crane";
            translator = "cargo-lock";
          }
        ];
        packageOverrides.indexer-deps.add-deps.overrideAttrs = old: {
          buildInputs = (old.buildInputs or []) ++ [openssl];
          nativeBuildInputs = (old.nativeBuildInputs or []) ++ [pkg-config];
        };
        packageOverrides.indexer.add-deps.overrideAttrs = old: {
          LIBSSH2_SYS_USE_PKG_CONFIG = 1;
          buildInputs = (old.buildInputs or []) ++ [libgit2 libssh2 openssl zlib curl];
          nativeBuildInputs = (old.nativeBuildInputs or []) ++ [pkg-config];
        };
      })
      .packages
      .default;
  in
    runCommandNoCC package.name {} ''
      ln -sf ${package}/bin/indexer $out
    '';
}
