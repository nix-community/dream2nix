<p align="center">
<img width="400" src="https://gist.githubusercontent.com/DavHau/755fed3774e89c0b9b8953a0a25309fa/raw/e2a12a60ae49aa5eb11b42775abdd1652dbe63c0/dream2nix-01.png">
</p>

## [WIP] dream2nix - A generic framework for 2nix tools

dream2nix is a generic framework for 2nix converters (converting from other build systems to nix).  
It focuses on the following aspects:

- Modularity
- Customizability
- Maintainability
- Nixpkgs Compatibility (not enforcing IFD)
- Code de-duplication across 2nix converters
- Code de-duplication in nixpkgs
- Risk free opt-in FOD fetching (no reproducibility issues)
- Common UI across 2nix converters
- Reduce effort to develop new 2nix solutions
- Exploration and adoption of new nix features
- Simplified updating of packages

The goal of this project is to create a standardized, generic, modular framework for 2nix solutions, aiming for better flexibility, maintainability and usability.

The intention is to integrate many existing 2nix converters into this framework, thereby improving many of the previously named aspects and providing a unified UI for all 2nix solutions.

### Watch the recent presentation
[![dream2nix - A generic framework for 2nix tools](https://gist.githubusercontent.com/DavHau/755fed3774e89c0b9b8953a0a25309fa/raw/3c8b2c56f5fca3bf5c343ffc179136eef39d4d6a/dream2nix-youtube-talk.png)](https://www.youtube.com/watch?v=jqCfHMvCsfQ)

### Further Reading

- [Summary of the core concepts and benefits](/docs/concepts-and-benefits.md)
- [How would this improve the packaging situation in nixpkgs](/docs/nixpkgs-improvements.md)
- [Override System](/docs/override-system.md)
- [Contributors Guide](/docs/contributors-guide.md)
