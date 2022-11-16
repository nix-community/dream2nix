import pytest
import nix_ffi

@pytest.mark.parametrize("expected, versions", [
    ('3', [ '2', '3', '1' ]),
])
def test_latestVersion(expected, versions):
    result = nix_ffi.callNixFunction('dlib.latestVersion', versions=versions)
    assert result == expected
