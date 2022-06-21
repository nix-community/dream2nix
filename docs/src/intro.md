# dream2nix

dream2nix is a framework for automatically converting packages from other build systems to nix.

It focuses on the following aspects:

- Modularity
- Customizability
- Maintainability
- Nixpkgs Compatibility, by not enforcing [IFD (import from derivation)][glossary]
- Code de-duplication across 2nix converters
- Code de-duplication in nixpkgs
- Risk-free opt-in aggregated fetching (larger [FODs][glossary], less checksums)
- Common UI across 2nix converters
- Reduce effort to develop new 2nix solutions
- Exploration and adoption of new nix features
- Simplified updating of packages

The goal of this project is to create a standardized, generic, modular framework for automated packaging solutions, aiming for better flexibility, maintainability and usability.

The intention is to integrate many existing 2nix converters into this framework, thereby improving many of the previously named aspects and providing a unified UX for all 2nix solutions.

### Further reading

- [Summary of the core concepts and benefits](./intro/concepts-and-benefits.md)
- [How would this improve the packaging situation in nixpkgs](./intro/nixpkgs-improvements.md)
- [Override System](./intro/override-system.md)
- [Contributors Guide](./contributing.md)
- [Extending dream2nix](./extending-dream2nix.md)
- [Subsystems](./subsystems.md)

[glossary]: https://nixos.wiki/wiki/Glossary "glossary"