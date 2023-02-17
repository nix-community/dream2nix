# Problems of the current dream2nix

## Integration of existing lang2nix tools
Until now, integrating existing 2nix solutions into dream2nix was hard because dream2nix imposed standards which are not met by most existing tools.
With v1 we want to lift most of these restrictions to make integration a no-brainer

(see sections [integrate lang2nix tool (pure)](../v1-api/integrate-lang2nix-pure.md) and [integrate lang2ix tool (impure)](../v1-api/integrate-lang2nix-impure.md).

## Tied to flakes
The current api is tied to flakes. The v1 API should not depend on flakes anymore.

## Composability
Composability with the current `makeFlakeOutputs` is bad. Flakes itself aren't nicely composable. Filtering and merging of nested attrsets isn't user friendly.

The v1 api will focus on delivering individual derivations, not flakes.
While we might provide templates, recommendations, and tools for composition, we should not enforce a specific solution onto the user.

## Overridability
The experience of overriding package- and dependency builds was a bit bumpy so far, as the overriding mechanism was built ontop of override functions provided by nixpkgs' `mkDerivation`. The v1 API will make use of the nixos module system instead to handle derivation attributes.

## Discoverability of package options
We want users to be able to inspect the API of an individual package. This will also be made possible by the nixos module system.
