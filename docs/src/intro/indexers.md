# Indexers

Indexers are programs that can query a package repository (think of npm, or crates.io) for package information.
This information mainly consists of the package name, the package version, and anything extra that might be useful / needed to fetch / translate it.
The information is stored as JSON (see below).

## Indexer inputs

Indexers take input as a path to a JSON file, which contains custom arguments for the indexer.
A common attribute for these inputs across indexers are `outputFile`, which should be the path to output the generated index to.
Indexers can vary in functionality, so these JSON inputs should be specified under `src/specifications/indexers/`.

## Indexer outputs

Indexers should output their generated index to where `outputFile` specifies.
This index should simply be a list of project specifications in JSON. Example:

```json
[
  {
    "name": "execa",
    "version": "6.1.0",
    "translator": ["npm"]
  },
  {
    "name": "meow",
    "version": "10.1.3",
    "translator": ["npm"]
  },
  {
    "name": "npm-run",
    "version": "5.0.1",
    "translator": ["npm"]
  }
]
```

## Current indexers

Following are the current indexers implemented in dream2nix:

- **crates-io-simple**: crates.io indexer
- **crates-io**: crates.io indexer written in rust with more options
- **libraries-io**: multi ecosystem indexer utilizing libraries.io (requires API key)
- **npm**: simple indexer using npm's registry
