{
  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";

    goblins.url = "gitlab:leungbk/goblins";
    goblins.flake = false;
  };

  outputs = {
    self,
    dream2nix,
    goblins,
  } @ inp: (dream2nix.lib.makeFlakeOutputs {
    systems = ["x86_64-linux"];
    config.projectRoot = ./.;
    source = goblins;
    projects = ./projects.toml;
  });
}
