import pytest
from pathlib import Path

import lock_file_from_report as l


def test_path_in_repo_root(monkeypatch, git_repo_path):
    def git_repo_root():
        return git_repo_path

    monkeypatch.setattr(l, "git_repo_root", git_repo_root)
    assert l.lock_info_from_path(git_repo_path / "foo") == ("foo", None)


def test_path_not_in_store_or_repo():
    with pytest.raises(Exception) as exc_info:
        l.lock_info_from_path(Path("/foo/bar"))
    assert "refers to something outside /nix/store" in str(exc_info.value)


def test_path_is_fod_output(monkeypatch, fod_store_path):
    assert l.lock_info_from_path(Path(fod_store_path)) == (
        "https://example.com",
        "3a3f9b030dcb0974ef85969c37f570349df9d74fb8abf34ed86fc5aae0bef42b",
    )
