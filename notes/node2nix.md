## problems with original node2nix implementation

### Bad caching
- packages are all unpacked at once inside a build instead of in individual derivations
- packages are unpackged several times in different directories (symlinks could be used)

### Bad build performance
 - unpacking is done sequentially
 - pinpointing deps is done sequentially

### build time dependencies unavailable
 - packages are not available during build (could be fixed by setting NODE_PATH and installing in correct order)
