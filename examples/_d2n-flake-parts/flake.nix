{
  inputs = {
    dream2nix.url = "path:../..";
    flake-parts.url = "github:hercules-ci/flake-parts";
    src.url = "github:BurntSushi/ripgrep/13.0.0";
    src.flake = false;
  };

  outputs = {
    self,
    dream2nix,
    flake-parts,
    src,
    ...
  }:
    flake-parts.lib.mkFlake {inherit self;} {
      imports = [dream2nix.flakePartsModule];
      systems = ["x86_64-linux"];
      dream2nix = {
        config.projectRoot = ./.;
        projects = [
          {
            source = src;
            settings = [{builder = "crane";}];
          }
        ];
      };
    };
}
