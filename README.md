## dream2nix - A generic framework for 2nix tools
dream2nix is an approach to create a generic framework for 2nix tools.
It focuses on the following aspects:
  - Modularity
  - Customizability
  - Maintainability
  - Code de-duplication across 2nix tools
  - Standardised UI across different solutions
  - Reduced effort to develop new 2nix solutions

### Motivation
2nix tools, or in other words, tools converting instructions of other build systems to nix build instructions, are an important part of the nix/nixos ecosystem. These tools make packaging workflows easier and often allow to manage complexity that would be hard/impossible to manage without the 2nix tools.

Yet the current landscape of 2nix tools has certain weaknesses. Existing 2nix tools are very monolithic. Authors of 2nix tools are often motivated by some specific use case they try to solve and therefore the individual approaches are strongly biased. All existing tools have quite different user interfaces, use different strategies of parsing, resolving, fetching, building. As a user of these tools it often feels like there is some part of the tool that suits the needs well, but at the same time it has undesirable hard coded behaviour. Often one would like to use some aspect of one tool, combined with some aspect of another tool. One tool, for example, might do a good job in reading a specific lock file format, but doesn't come with good customizability for building. Another tool might come with a good customization interface, but lacks the capabilities of parsing the lock file format provided by upstream. Some tools are restricted to use IFD or FOD, while others enforce code generation.

The idea of this project is therefore to create a standardized, generic, modular, framework for 2nix tools, aiming for better flexibility, maintainability and usability.

### Modularity:
Individual phases like:
  - parsing requiremnts
  - resolving/locking dependencies
  - fetching sources
  - building/installing packages

... should be separated from each other with well defined interfaces.  
This will allow a free compsition of different approaches for these phases.
Examples:
  - Often more than one requirements / lock-file format exists within an ecosystem. Switching between these formats, or adding support for a new one should be easy.
  - Different resolving/fetching strategies: Some users might prefer a more automated approach via IFD or FOD, while others are focusing on upstreaming stuff to nixpkgs, where generating intermediary code or lock-files might be the only option.
  - Fetching a list of sources in theory should be a standard process. Yet, in practice, many 2nix tools struggle fetching sources from git or including local source trees. A generic fetching layer can reduce effort for maintainers.

### Customizability
Every Phase mentioned in the previous section should be customizable at a high degree via override functions. Examples:
  - Inject extra requirements/dependencies
  - fetch sources from alternative locations
  - replace or modify sources
  - customize the build/installation procedure


### Maintainability
Due to the modular architecture with well defined interfaces, contributers can add support for new lock-file formats or new strategies for fetching, building, installing more easily.


### Architecture
The general architecture should be like this:  
`Input -> Translation -> URLs, metadata -> Fetching -> Building`

```
┌───────┐
│ Input │◄──── Arbitrary
└────┬──┘                   Build instructions in standardized
     │   ┌───────────┐      minimalistic form (json)
     └──►│Translation│          │
         └────────┬──┘          ▼
           ▲      │   ┌──────────────┐
           │      └──►│URLs, metadata│
                      └───────────┬──┘             reads instructions
 impure/pure                      │   ┌────────┐   from metadata
 online/offline                   └──►│Fetcher │      │
 IFD/FOD/external                     └─────┬──┘      ▼
                                            │   ┌────────┐
                                            └──►│Builder │
                                                └────────┘
```

Input:
  - requirement contsraints
  - requirement files
  - lock-files

Translation:
  - read input and generate standardized output format containing URLs + hashes for sources and metadata required for the build
  - different strategies can be used to achieve the required output:
    - impure translation: resolve against online package index
    - pure translation (IFD compatible): resolve against offline package index
    - pure translation (FOD compatible): resolve against online index, reproducibly

URLs, metadata (standardized format):
  - Produced by `Translation`. Contains URLs + hashes for sources and metadata relevant for building. The basic format is standardized and equivalent across all languages/frameworks, so that fetching works always the same. It is not relevant which steps/strategies have been taken to create this data. From this point on, there are no impurities. This format will contain everything necessary for a fully reproducible build. The metadata allows different attributes for different languages/frameworks as those require individual approaches. A specific builder for every framework will later read this metadata and translate it to build instructions.
  This format can always be copied into nixpkgs, not requiring any IFD (given the nix code for the builder exists within nixpkgs).

Fetching:
  - Since a generic format was produced in the previous step, the fetching layer can be the same across all languages and frameworks.

Building:
  - Inputs are the fetched sources coming from the fetcher and the metadata produced by the Translation layer. The builder now transforms the metadata into build instructions.

