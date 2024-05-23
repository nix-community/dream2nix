from pathlib import Path
import pytest
import lock_file_from_report as l


def test_nothing_requested():
    report = dict(
        environment=dict(),
        install=[
            dict(
                metadata=dict(
                    name="test",
                    version="0.0.0",
                ),
                download_info=dict(url="https://example.com"),
            )
        ],
    )
    with pytest.raises(Exception) as exc_info:
        l.lock_file_from_report(report)
        assert "Cannot determine roots" in exc_info.value


def test_simple():
    report = dict(
        environment=dict(),
        install=[
            dict(
                requested=True,
                metadata=dict(
                    name="test",
                    version="0.0.0",
                ),
                is_direct=False,
                download_info=dict(url="https://example.com"),
            )
        ],
    )
    expected = dict(
        sources=dict(
            test=dict(
                type="url",
                sha256=None,
                url="https://example.com",
                version="0.0.0",
                is_direct=False,
            )
        ),
        targets=dict(
            default=dict(
                test=[],
            ),
        ),
    )
    assert l.lock_file_from_report(report, Path("/beer")) == expected


def test_multiple_requested():
    report = dict(
        environment=dict(),
        install=[
            dict(
                requested=True,
                metadata=dict(
                    name="foo",
                    version="0.0.0",
                ),
                download_info=dict(url="https://example.com"),
                is_direct=False,
            ),
            dict(
                requested=True,
                metadata=dict(
                    name="bar",
                    version="0.0.0",
                ),
                is_direct=True,
                download_info=dict(url="https://example.com"),
            ),
        ],
    )
    expected = dict(
        sources=dict(
            foo=dict(
                type="url",
                sha256=None,
                url="https://example.com",
                version="0.0.0",
                is_direct=False,
            ),
            bar=dict(
                type="url",
                sha256=None,
                url="https://example.com",
                version="0.0.0",
                is_direct=True,
            ),
        ),
        targets=dict(
            default=dict(
                foo=[],
                bar=[],
            ),
        ),
    )
    assert l.lock_file_from_report(report, Path("foo")) == expected
