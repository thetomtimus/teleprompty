#!/usr/bin/env python3
"""Generate and verify the sole synthetic Milestone 5 performance fixture."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

WORD_COUNT = 50_000
LINE_WIDTH = 20
EXPECTED_UTF8_BYTES = 499_999
EXPECTED_UTF16_UNITS = 499_999
EXPECTED_NEWLINES = 2_499
EXPECTED_DIGEST = "d2aff66f0796536318d97d3b1d8080247728798dfa110725994019d58e7b09f4"


def generate_fixture(word_count: int) -> bytes:
    if word_count != WORD_COUNT:
        raise ValueError(f"--words must be exactly {WORD_COUNT}")
    parts: list[str] = []
    for index in range(word_count):
        parts.append(f"word{index:05d}")
        if index + 1 < word_count:
            parts.append("\n" if (index + 1) % LINE_WIDTH == 0 else " ")
    encoded = "".join(parts).encode("utf-8")
    verify_fixture(encoded)
    return encoded


def verify_fixture(data: bytes) -> None:
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as error:
        raise ValueError("fixture is not valid UTF-8") from error
    words = text.split()
    failures: list[str] = []
    if len(words) != WORD_COUNT:
        failures.append(f"word-count={len(words)}")
    if len(data) != EXPECTED_UTF8_BYTES:
        failures.append(f"utf8-bytes={len(data)}")
    utf16_units = len(text.encode("utf-16-le")) // 2
    if utf16_units != EXPECTED_UTF16_UNITS:
        failures.append(f"utf16-units={utf16_units}")
    if not words or words[0] != "word00000":
        failures.append("first-token")
    if not words or words[-1] != "word49999":
        failures.append("last-token")
    if data[250_000:250_009] != b"word25000":
        failures.append("middle-token")
    if data.endswith(b"\n"):
        failures.append("final-newline")
    newline_count = data.count(b"\n")
    if newline_count != EXPECTED_NEWLINES:
        failures.append(f"newlines={newline_count}")
    digest = hashlib.sha256(data).hexdigest()
    if digest != EXPECTED_DIGEST:
        failures.append(f"sha256={digest}")
    if failures:
        raise ValueError("fixture contract drift: " + ", ".join(failures))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--words", type=int)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.self_test:
        if args.words is not None or args.output is not None:
            parser.error("--self-test cannot be combined with --words or --output")
    elif args.words is None or args.output is None:
        parser.error("generation requires --words 50000 and --output PATH")
    return args


def main() -> int:
    args = parse_args()
    fixture = generate_fixture(WORD_COUNT if args.self_test else args.words)
    if not args.self_test:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_bytes(fixture)
        if args.output.read_bytes() != fixture:
            raise RuntimeError("written fixture bytes changed during output verification")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
