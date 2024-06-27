# Thoughts on the current nixos module system

This document covers observed problems with the current nixos module system that arose after using it for dream2nix and proposes changes to the module system.

## Problem 1: Bad control over module dependencies

It is easy to depend on a module unintentionally.

It is hard to guarantee that a module works with a limited set of other modules.

A module can import arbitrary paths, which makes it hard to limit the modules of the evaluation.

## Problem 2: Module identification/duplication issues

References to the same module in different ways (file vs imported file), are sometimes accidentally detected as two different modules leading to a collision error.

It is possible to prevent this by setting `_file`, but this still not optimal, as not all modules are forced to define this field.
Not having a unique ID by default is not optimal.

## Problem 3: Result type and location not discoverable

Usually the evaluation of a set of modules leads to a result or a set of results. But neither the type of the result nor the location of the result within `config` can be discovered by the caller without looking at the modules implementation.

For example NixOS exports the results via `config.system`, drv-parts uses `config.public` etc.
For the user calling `evalModules` it is not clear how exactly to get to the final result out of the evaluation.

Strictly speaking, the result is the `config`, but apart from the final result, `config` also contains other things, like user interfaces and intermediary result. This confuses a user who is only interested in the final result.

## Problem 4: Unprotected gloabl scope
Using the global scope to pass data between modules is not optimal, because:
- collisions: option declarations and definitions of different modules can collide accidentally.
- unlimited access: A module can read and write to arbitrary fields of arbitrary other modules by default. This can result in unwanted side effects and hidden dependencies on other modules. Even if a module doesn't declare a dependency on module X it can depend on module X setting some option of module Y correctly. These unwanted interactions can be very complex and hard to find and prevent.

Considered workaround:
We established the following pattern:

- Each module prefixes all its options with the modules name, for example:
  - module `mkDerivation` defines options `mkDerivation.src` and `mkDerivation.buildPhase`
  - module `buildPythonPackages` defines options `buildPythonPackage.format` ...

Benefit of the workaround:
This prevents collisions (assuming module names are unique)

Disadvantage of the workaround:

- It still allows global read/write access between all modules.
- It prevents composition of interfaces: We cannot nicely mix the options of `mkDerivation` and `buildPythonPackage` to create a new module, as all options have a hardcoded prefix that cannot be changed anymore
- Using the module as submodule is more annoying, as because of the hardcoded prefix, it always adds an additional layer of nesting that might not be desired.

## Proposal 1

Solves:

- Problem 1 (Bad control over module dependencies)
- Problem 2 (Module identification/duplication issues)

Proposed Changes:

- generally separate `dependency declaration` from `dependency satisfaction`
- for example, add a flag to evalModules that changes the behavior of `imports`
- force modules to declare `imports` by name (never by path)
- have a `resolver` resolving requested names against a set of named modules provided by the user
- allow inspecting the requested dependencies before evaluation

Effects:

- users can discover module dependencies
- users can override the resolved module and thereby replace it's implementation
- maintainers can discover and prevent hidden dependencies easily
- lay the grounds for better input management (derive flake inputs from modules)

## Proposal 2

Solves:

- Problem 3 (Result type and location not discoverable)

Proposed Changes:

- standardize a specific field under config to contain the final result(s), like for example `config.exports`.

Effects:

- the result type is discoverable by inspecting the type of `options.exports`
- allows adding helper `callModule` which is like `evalModules` but just returns the result.
- allows users to treat modules like functions that can be called and return a result.
- modules are more approachable by high-level users
- modules are more portable.

## Proposal 3

Solves:

- Problem 4 (Unprotected global scope)

Proposed Changes:

- disallow nested option declarations
- disallow inline definitions for submodules

(This limitation could be toggled via a flag in evalModules)

Effects:

- This forces maintainers to use submodules (defined in files) to create nested options
- This leads to an extensive use of submodules
- Using submodules encourages passing information explicitly between modules while discouraging the use of global fields for communication
