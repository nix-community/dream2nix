import pytest
from pathlib import Path

import lock_file_from_report as l


def test_path_in_repo_root(git_repo_path):
    assert l.lock_info_from_path(git_repo_path / "foo", git_repo_path) == ("foo", None)


def test_path_not_in_store_or_repo():
    with pytest.raises(Exception) as exc_info:
        l.lock_info_from_path(Path("/foo/bar"), Path("/beer"))
    assert "refers to something outside /nix/store" in str(exc_info.value)


def test_path_is_fod_output(monkeypatch):
    fod_store_path = "/nix/store/test"

    def nix_show_derivation(store_path):
        return dict(
            env=dict(
                urls="https://example.com",
            ),
            outputs=dict(
                out=dict(
                    hash="3a3f9b030dcb0974ef85969c37f570349df9d74fb8abf34ed86fc5aae0bef42b",
                    hashAlgo="r:sha256",
                    path=fod_store_path,
                )
            ),
        )

    monkeypatch.setattr(l, "nix_show_derivation", nix_show_derivation)
    assert l.lock_info_from_path(Path(fod_store_path), Path("/foo")) == (
        "https://example.com",
        "3a3f9b030dcb0974ef85969c37f570349df9d74fb8abf34ed86fc5aae0bef42b",
    )
