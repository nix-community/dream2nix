# Website

This directory contains markdown pages under ./src which are rendered to an html website using the tool mdbook.

The website can be built via:
```shellSession
$ nix build .#website
```

In addition to what's already in ./src, this derivation generates and inserts reference documentation pages. One for each dream2nix module in /modules/dream2nix.
