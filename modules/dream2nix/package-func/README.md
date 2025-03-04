---
title: "package-func"
state: "internal"
maintainers:
  - DavHau
---

Module to provide an interface for integrating derivation builder functions like mkDerivation, buildPythonPackage, etc...

## Package format

package-func calls the derivation builder function `package-func.func` with arguments supplied in `package-func.args` and wraps the result into the a package that is exposed under `config.public`. The raw result is avaliable as `package-func.result`.

The final package contains the following attributes:

- `config`: the config used to product the existing package
- `extendModules`: a helper function that allows to extend an existing package with another module
- `outputPath`: the store path of the result of the default top-level output
- `drvPath`; the store path of the instantiated derivation of top-level output
- `outputName`: the name of the default top-level output

In addition, it contains an attribute of the same name for each output declared in `package-func.outputs`, mapping the output name to the corresponding output of evaluated result.

## Top-level output

The top-level output exposed in the final package is selected from `package-func.outputs`.

For a single-output derivations, the sole output is used as the top-level output. For multi-output derivations, the first output specified in outputs or the default output (if the attribute `outputSpecified` is true) is used as the top-level output.