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
  sources = dict(
    example = {
      "1.2.3": dict(
        type = "path",
        rootName = None,
        rootVersion = None,
        relPath = "a/b/c",
      ),
    },
  ),
)

def test_dream_lock_inject():
  result = nix_ffi.callNixFunction(
    'utils.dream-lock.injectDependencies',
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

def test_dream_lock_replace_root_sources():
  result = nix_ffi.callNixFunction(
    'utils.dream-lock.replaceRootSources',
    dreamLock=exampleDreamLock,
    newSourceRoot=dict(
      type = "http",
      url = "something",
    ),
  )
  assert result['sources']['example']['1.2.3'] == dict(
    type = "http",
    url = "something",
    dir = "a/b/c",
  )