import pytest
import nix_ffi

exampleDreamLock = dict(
  _generic = dict(
    defaultPackage="example",
    packages=dict(
      example="1.2.3",
    ),
    subsystem = "nodejs",
    _subsystemAttrs = {},
  ),
  dependencies = {},
  cyclicDependencies = {},
  sources = {},
)

def test_dream_lock_inject():
  result = nix_ffi.callNixFunction(
    'utils.dreamLock.injectDependencies',
    dreamLock=exampleDreamLock,
    inject=dict(
      example={
        "1.2.3": [
          [ "injected-package", "1.0.0" ]
        ]
      }
    ),
  )
  assert result['dependencies']['example']['1.2.3'] == [dict(
    name="injected-package",
    version="1.0.0",
  )]
