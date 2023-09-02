import pytest
from packaging.requirements import Requirement

import lock_file_from_report as l


def test_url_no_hash():
    install = dict(
        metadata=dict(
            name="test",
            version="0.0.0",
        ),
        download_info=dict(url="https://example.com"),
    )
    expected = "test", dict(
        type="url",
        url=install["download_info"]["url"],
        version=install["metadata"]["version"],
        sha256=None,
    )
    assert l.lock_entry_from_report_entry(install) == expected


def test_url_with_hash():
    install = dict(
        metadata=dict(
            name="test",
            version="0.0.0",
        ),
        download_info=dict(
            url="https://example.com",
            archive_info=dict(hash=f"sha256=example_hash"),
        ),
    )
    expected = "test", dict(
        type="url",
        url=install["download_info"]["url"],
        version=install["metadata"]["version"],
        sha256="example_hash",
    )
    assert l.lock_entry_from_report_entry(install) == expected


def test_path_external():
    install = dict(
        metadata=dict(
            name="test",
            version="0.0.0",
        ),
        download_info=dict(
            url="/foo/bar",
        ),
    )
    expected = "test", dict(
        type="url",
        url=install["download_info"]["url"],
        version=install["metadata"]["version"],
        sha256=None,
    )
    assert l.lock_entry_from_report_entry(install) == expected


def test_path_in_repo(git_repo_path):
    install = dict(
        metadata=dict(
            name="test",
            version="0.0.0",
        ),
        download_info=dict(
            url=git_repo_path.name,
        ),
    )
    expected = "test", dict(
        type="url",
        url=install["download_info"]["url"],
        version=install["metadata"]["version"],
        sha256=None,
    )
    assert l.lock_entry_from_report_entry(install) == expected


def test_path_in_nix_store():
    install = dict(
        metadata=dict(
            name="test",
            version="0.0.0",
        ),
        download_info=dict(
            url="/nix/store/test",
        ),
    )
    expected = "test", dict(
        type="url",
        url=install["download_info"]["url"],
        version=install["metadata"]["version"],
        sha256=None,
    )
    assert l.lock_entry_from_report_entry(install) == expected
