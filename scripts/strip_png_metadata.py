"""Remove EXIF/comments from explicit publication PNGs without re-encoding pixels."""

import argparse
from pathlib import Path
import os
import stat
import struct
import tempfile

from check_public_snapshot import PNG_MAGIC, approved_png, valid_png

# Machine-specific color profiles can carry descriptive strings. Leave the compressed pixels intact.
REMOVABLE_CHUNKS = {b"iCCP", b"eXIf", b"iTXt", b"tEXt", b"zTXt", b"tIME"}


def without_metadata(data):
    if not data.startswith(PNG_MAGIC):
        raise ValueError("expected a PNG")
    chunks = [PNG_MAGIC]
    offset = len(PNG_MAGIC)
    while offset < len(data):
        if offset + 12 > len(data):
            raise ValueError("truncated chunk")
        length, kind = struct.unpack_from(">I4s", data, offset)
        end = offset + length + 12
        if end > len(data):
            raise ValueError("invalid chunk framing")
        if kind not in REMOVABLE_CHUNKS:
            chunks.append(data[offset:end])
        offset = end
        if kind == b"IEND" and offset != len(data):
            raise ValueError("unexpected bytes after IEND")
    cleaned = b"".join(chunks)
    if not valid_png(cleaned):
        raise ValueError("result has malformed or non-allowlisted chunks")
    return cleaned


def strip_file(path):
    original = path.read_bytes()
    cleaned = without_metadata(original)
    if cleaned == original:
        return False
    mode = stat.S_IMODE(path.stat().st_mode)
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as temp:
        replacement = Path(temp.name)
        try:
            temp.write(cleaned)
            temp.flush()
            os.chmod(replacement, mode)
            os.replace(replacement, path)
        finally:
            replacement.unlink(missing_ok=True)
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="+", type=Path)
    args = parser.parse_args()
    for path in args.paths:
        if not approved_png(path) or path.is_symlink() or not path.is_file():
            parser.error("provide repository-relative AppIcon or docs/demo PNG paths")
        try:
            changed = strip_file(path)
        except ValueError as error:
            parser.error(str(error))
        print(f"{path}: {'metadata removed' if changed else 'already clean'}")


if __name__ == "__main__":
    main()
