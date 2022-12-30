{
  nodejs,
  pkg,
  pkgs,
}:
with pkgs;
  mkShell {
    buildInputs = [
      nodejs
    ];
    shellHook = let
      nodeModulesDir = pkg.deps;
    in ''
      # rsync the node_modules folder
      # is way faster than copying everything again, because it only replaces updated files

      # current Options:
      # -a -> all files recursive, preserve symlinks, etc.
      # -c -> calculate hashsums
      # -E -> preserve executables
      # --delete -> removes deleted files
      ${rsync}/bin/rsync -acE --delete ${nodeModulesDir}/* ./node_modules/

      chmod -R +w ./node_modules
      export PATH="$PATH:$(realpath ./node_modules)/.bin"
    '';
  }
