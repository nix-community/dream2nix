## problems with original node2nix implementation

### Bad caching
- packages are all unpacked at once inside a build instead of in individual derivations

### Bad build performance
 - unpacking is done sequentially
 - pinpointing deps is done sequentially

### build time dependencies unavailable
 - packages are not available during build (could be fixed by setting NODE_PATH and installing in correct order)
