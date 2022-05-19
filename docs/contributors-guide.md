# dream2nix contributers guide

## Translator Notes

In general there are 3 different types of translators

1. pure translator

   - translation logic is implemented in nix lang only
   - does not invoke build or read from any build output

2. pure translator utilizing IFD (import from derivation)

   - part of the logic is integrated as a nix build
   - nix code is used to invoke a nix build and parse its results
   - same interface as pure translator

3. impure

   - translator can be any executable program running outside of a nix build
   - not constrained in any way (can do arbitrary network access etc.)

## Initialize a new translator

Clone dream2nix repo and execute:
```shell
nix run .#contribute
```
... then select `translator` and answer all questions. This will generate a template.

Further instructions are contained in the template in form of code comments.

## Debug or test a translator
### Unit tests (pure translators only)
Unit tests will automatically be generated as soon as your translator specifies `generateUnitTestsForProjects`.
Unit tests can be executed via `nix run .#tests-unit`
### Repl debugging

- temporarily expose internal functions of your translator
- use nix repl `nix repl ./.`
- invoke a function via
   `translators.translators.{subsystem}.{type}.{translator-name}.some_function`

### Tested example flake
Add an example flake under `./examples/name-of-example`.
The flake can be tested via:
```command
nix run .#tests-examples name-of-example --show-trace
```
The flake will be tested in the CI-pipeline as well.


---

## Initialize a new builder

Clone dream2nix repo and execute:
```shell
nix run .#contribute
```
... then select `builder` and answer all questions. This will generate a template.

Further instructions are contained in the template in form of code comments.

## Debug or test a builder

### Tested example flake
Add an example flake under `./examples/name-of-example`.
The flake can be tested via:
```command
nix run .#tests-examples name-of-example --show-trace
```
The flake will be tested in the CI-pipeline as well.
