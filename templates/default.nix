{
  lib,
  self,
  ...
}: let
  l = lib // builtins;
in {
  flake = {
    templates =
      {
        default = self.templates.simple;
        simple = {
          description = "Simple dream2nix flake";
          path = ./templates/simple;
          welcomeText = ''
            You just created a simple dream2nix package!

            start with typing `nix flake show` to discover the projects attributes.

            commands:

            - `nix develop` <-- enters the devShell
            - `nix build .#` <-- builds the default package (`.#default`)


            Start hacking and -_- have some fun!

            > dont forget to add nix `result` folder to your `.gitignore`

          '';
        };
      }
      // (
        l.genAttrs
        (self.lib.dlib.listDirs ../examples)
        (name: {
          description = "Example: ${name} template";
          path = ../examples/${name};
        })
      );
  };
}
