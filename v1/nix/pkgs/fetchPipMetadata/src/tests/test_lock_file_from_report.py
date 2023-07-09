import pytest
import lock_file_from_report as l


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
                download_info=dict(url="https://example.com"),
            )
        ],
    )
    expected = dict(
        sources=dict(
            test=dict(
                sha256=None,
                url="https://example.com",
                version="0.0.0",
            )
        ),
        targets=dict(
            default=dict(
                test=[],
            ),
        ),
    )
    assert l.lock_file_from_report(report) == expected
