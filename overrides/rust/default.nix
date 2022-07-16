{
  lib,
  pkgs,
  ...
}: let
  l = lib // builtins;
  addDeps = bi: nbi: {
    overrideAttrs = old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ nbi;
      buildInputs = (old.buildInputs or []) ++ bi;
    };
  };
in rec {
  zellij-deps = {
    add-deps = with pkgs; addDeps [openssl] [pkg-config];
  };
  zellij = {
    inherit-deps = zellij-deps.add-deps;
    add-deps = with pkgs; addDeps [zlib] [];
  };
  eureka-deps = {
    add-deps = with pkgs; addDeps [openssl] [pkg-config];
  };
  eureka = {
    inherit-deps = eureka-deps.add-deps;
    add-deps = with pkgs; addDeps [zlib] [];
    # the tests seem to be undeterministic if ran in parallel
    disable-parallel-tests.RUST_TEST_THREADS = 1;
  };
}
