## Why not just wrap haskell.nix and use it as is?

Haskell.nix has the following problems which we like to prevent:

### 1. nix code generation enforced

haskell.nix always generates nix code as an intermediary step. This forcefully requires IFD or pre-processing (materialization) which negatively impacts performance and/or UX.

In dream2nix, processing of the input is preferably done in nix, which minimizes IFD layers required and should lead to better overall evaluation performance and less complex UX. For situations where a pure nix translation is not possible, dream2nix also falls back to IFD or pre-processing (impure translation), but this is well integrated in the UI and won't require studying an extra readme for materialization or manually having to check if materialization artifacts are up to date.

### 2. caching
haskell.nix contains a lot of overlays for nixpkgs and custom patches for ghc. This seems to invalidate artifacts from the nixos.org cache to a degree where using haskell.nix becomes practically impossible without trusting iohk's cache or hosting ones own caching infrastructure.

One goal of dream2nix is to integrate better with the nixos.org infrastructure:
  - by trying to re-use cached compilers from nixpkgs
  - by generally being compatible with nixpkgs, so dream2nix made packages can be added to nixpkgs directly and therefore will be cached on nixos.org.
  - by finally releasing the whole dream2nix framework into nixpkgs leading to an optimal integration with the official infra.

### 3. simple operations are too expensive
Simple operations, like listing packages for a project, already requires IFD or pre-processing. Tooling around nix, especially flakes + nix-command expects these kind of operations to be cheap and quick in execution. This is currently not provided by haskell.nix.
