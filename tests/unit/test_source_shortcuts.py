import pytest
import nix_ffi


@pytest.mark.parametrize(
    "shortcut, expected",
    [
        (
            "https://foo",
            dict(
                type="http",
                url="https://foo",
            ),
        ),
        (
            "http://foo/bar",
            dict(
                type="http",
                url="http://foo/bar",
            ),
        ),
        (
            "github:owner/repo/v1.2.3",
            dict(
                type="github",
                owner="owner",
                repo="repo",
                rev="v1.2.3",
            ),
        ),
        # with arguments
        (
            "git+ssh://github.com/owner/repo?rev=refs/heads/v1.2.3&dir=sub/dir",
            dict(
                type="git",
                url="ssh://github.com/owner/repo",
                rev="refs/heads/v1.2.3",
                dir="sub/dir",
            ),
        ),
        (
            "http://foo/bar?kwarg1=foo&dir=sub/dir",
            dict(
                type="http",
                url="http://foo/bar?kwarg1=foo",
                dir="sub/dir",
            ),
        ),
        (
            "github:owner/repo/v1.2.3?kwarg1=foo&dir=sub/dir",
            dict(
                type="github",
                owner="owner",
                repo="repo",
                rev="v1.2.3",
                kwarg1="foo",
                dir="sub/dir",
            ),
        ),
        (
            "github:photoview/photoview/master?dir=lol",
            dict(
                type="github",
                owner="photoview",
                repo="photoview",
                rev="master",
                dir="lol",
            ),
        ),
    ],
)
def test_translateShortcut(shortcut, expected):
    result = nix_ffi.callNixFunction(
        "functions.fetchers.translateShortcut",
        shortcut=shortcut,
        computeHash=False,
    )
    assert result == expected
