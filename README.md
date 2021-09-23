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

### Motivation
2nix converters, or in other words, tools converting instructions of other build systems to nix build instructions, are an important part of the nix/nixos ecosystem. These converters make packaging workflows easier and often allow to manage complexity that would be hard or impossible to manage without.

Yet the current landscape of 2nix converters has certain weaknesses. Existing 2nix converters are very monolithic. Authors of these converters are often motivated by some specific use case and therefore the individual approaches are strongly biased and not flexible. All existing converters have quite different user interfaces, use different strategies of parsing, resolving, fetching, building with significantly different options for customizability. As a user of these converters it often feels like there is some part of it that suits the needs well, but at the same time it has undesirable hard coded behaviour. Often one would like to use some aspect of one converter combined with some aspect of another converter. One converter might do a good job in reading a specific lock file format, but lacks customizability for building. Another converters might come with a good customization interface, but is unable to parse the lock file format. Some tools are restricted to use IFD or FOD, while others enforce code generation.

The idea of this project is therefore to create a standardized, generic, modular framework for 2nix solutions, aiming for better flexibility, maintainability and usability.

The plan is to integrate many existing 2nix converters into this framework, and thereby improving many of the previously named aspects and providing a unified UI for all 2nix solutions.

### Further Reading
- [Summary of the core concepts and benefits](/docs/concepts-and-benefits.md)
- [How would this improve the packaging situation in nixpkgs](/docs/nixpkgs-improvements.md)





