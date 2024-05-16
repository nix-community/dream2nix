from pathlib import Path
from packaging.requirements import Requirement
import lock_file_from_report as l


def metadata(**kwargs):
    return dict(
        metadata=dict(
            name="test",
            version="0.0.0",
        ),
        is_direct=False,
        **kwargs,
    )


def expect(install, sha256=None):
    return "test", dict(
        type="url",
        url=install["download_info"]["url"],
        version=install["metadata"]["version"],
        sha256=sha256,
        is_direct=install["is_direct"],
    )


def test_url_no_hash():
    install = metadata(
        download_info=dict(url="https://example.com"),
    )
    expected = expect(install)
    assert l.lock_entry_from_report_entry(install, Path("foo")) == expected


def test_url_with_hash():
    install = metadata(
        download_info=dict(
            url="https://example.com",
            archive_info=dict(hash=f"sha256=example_hash"),
        ),
    )
    expected = expect(install, sha256="example_hash")
    assert l.lock_entry_from_report_entry(install, Path("foo")) == expected


def test_path_external():
    install = metadata(
        download_info=dict(
            url="/foo/bar",
        ),
    )
    expected = expect(install)
    assert l.lock_entry_from_report_entry(install, Path("foo")) == expected


def test_path_in_repo(git_repo_path):
    install = metadata(
        download_info=dict(
            url=git_repo_path.name,
        ),
    )
    expected = expect(install)
    assert l.lock_entry_from_report_entry(install, Path("foo")) == expected


def test_path_in_nix_store():
    install = metadata(
        download_info=dict(
            url="/nix/store/test",
        ),
    )
    expected = expect(install)
    assert l.lock_entry_from_report_entry(install, Path("foo")) == expected


def test_git(monkeypatch):
    def nix_prefetch_git(url, rev):
        return "f1bd065cf727c988b605787fd9f75a827a210a2b2ad56965f7d04e9ef80bcd7c"

    monkeypatch.setattr(l, "nix_prefetch_git", nix_prefetch_git)

    install = {
        "download_info": {
            "url": "https://github.com/python/mypy",
            "vcs_info": {
                "vcs": "git",
                "commit_id": "df4717ee2cbbeb9e47fbd0e60edcaa6f81bbd7bb",
            },
        },
        "metadata": {
            "metadata_version": "2.1",
            "name": "mypy",
            "version": "1.7.0+dev.df4717ee2cbbeb9e47fbd0e60edcaa6f81bbd7bb",
        },
        "is_direct": True,
    }
    expected = "mypy", {
        "rev": "df4717ee2cbbeb9e47fbd0e60edcaa6f81bbd7bb",
        "sha256": "f1bd065cf727c988b605787fd9f75a827a210a2b2ad56965f7d04e9ef80bcd7c",
        "type": "git",
        "url": "https://github.com/python/mypy",
        "version": "1.7.0+dev.df4717ee2cbbeb9e47fbd0e60edcaa6f81bbd7bb",
        "is_direct": True,
    }
    assert l.lock_entry_from_report_entry(install, Path("foo")) == expected
