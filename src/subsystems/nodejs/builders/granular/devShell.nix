/*
devShell allowing for good interop with npm

The shellHook always overwrites existing ./node_modules with a full
flat copy of all transitive dependencies produced by dream2nix from
the lock file.

This allows good interop with npm. npm is still needed to update or
add dependencies. npm can write to the ./node_modules without
any issues and add or replace dependencies.

If npm modifies ./node_modules, then its contents will be a mix of
dream2nix installed packages and npm installed packages until the
devShell is re-entered and dream2nix overwrites the ./node_modules
with a fully reproducible copy again.
*/
{
  mkShell,
  nodejs,
  devModules,
}:
mkShell {
  buildInputs = [nodejs];
  # TODO implement copy, maybe
  shellHook =
    if devModules != null
    then ''
      # create the ./node_modules directory
      if [ -e ./node_modules ] && [ ! -L ./node_modules ]; then
        echo -e "\nFailed creating the ./node_modules symlink to '${devModules}'"
        echo -e "\n./node_modules already exists and is a directory, which means it is managed by another program. Please delete ./node_modules first and re-enter the dev shell."
      else
        rm -f ./node_modules
        ln -s ${devModules} ./node_modules
        export PATH="$PATH:$(realpath ./node_modules)/.bin"
      fi
    ''
    else "";
}
