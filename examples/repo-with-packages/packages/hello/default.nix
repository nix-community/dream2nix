{
  dream2nix,
  config,
  lib,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.mkDerivation
  ];

  name = "hello";
  version = "2.12.1";

  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      stdenv
      ;
  };

  env = lib.optionalAttrs config.deps.stdenv.hostPlatform.isDarwin {
    NIX_LDFLAGS = "-liconv";
  };

  mkDerivation = {
    src = builtins.fetchTarball {
      url = "https://ftp.gnu.org/gnu/hello/hello-${config.version}.tar.gz";
      sha256 = "0xw6cr5jgi1ir13q6apvrivwmmpr5j8vbymp0x6ll0kcv6366hnn";
    };
  };
}
