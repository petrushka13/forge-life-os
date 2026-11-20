"""Check a proposed release tree and the Git history reachable from its public refs.

The rules flag known risky patterns. They do not establish ownership, licensing,
or the privacy of rendered image pixels. Review those separately before upload.
"""

import argparse
from pathlib import Path, PurePosixPath
import os
import re
import struct
import subprocess
import sys
import zlib

MAX_FILE_BYTES = 16 * 1024 * 1024
TEXT_EXTENSIONS = {
    ".entitlements", ".example", ".js", ".json", ".md", ".pbxproj", ".plist",
    ".py", ".sh", ".swift", ".txt", ".xcconfig", ".xcprivacy", ".xcscheme", ".yml", ".yaml",
}
TEXT_FILENAMES = {".gitignore", ".gitattributes", ".vscodeignore", "LICENSE", "NOTICE"}
PRIVATE_PARTS = {
    ".build", ".codex", ".swiftpm", ".ds_store", "deriveddata", "xcuserdata", "__pycache__",
    ".aws", ".ssh", "artifacts", "backups",
}
PRIVATE_ENDINGS = (
    ".app", ".ipa", ".appex", ".log", ".xcarchive", ".xcresult", ".store",
    ".store-wal", ".store-shm", ".sqlite", ".sqlite-wal", ".sqlite-shm", ".db",
    ".mobileprovision", ".provisionprofile", ".p12", ".pfx", ".pem", ".key", ".vsix",
    ".bak", ".zip", ".dmg", ".tar", ".gz", ".pdf",
)
RULES = {
    "private key": r"-----BEGIN (?:[A-Z]+ )*PRIVATE KEY-----",
    "GitHub token": r"\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})",
    "provider key": r"\bsk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{25,}",
    "AWS key identifier": r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b",
    "literal credential": r'(?im)^\s*(?:FORGE_PROXY_TOKEN|FORGE_INGEST_TOKEN|OPENAI_API_KEY|GITHUB_TOKEN|GH_TOKEN)\s*=\s*["\x27]?[A-Za-z0-9_+/=-]{20,}',
    "credentials in a URL": r"https?://[^/\s:@]+:[^/\s@]+@",
    "workstation path": (
        r"(?i)(?:[/]Users/[^/\s]+|[/]home/[^/\s]+|[/](?:private/)?var/folders/"
        r"|[/]private/tmp/forge[-/]|[A-Z]:\\Users\\)"
    ),
    "local identity": r"(?i)\b[\w.+-]+@[\w.-]+\.local\b",
    "device identifier field": r'(?i)"(?:deviceId|serialNumber|UDID)"\s*:',
    "Apple hardware identifier": r"(?i)\b[0-9a-f]{8}-[0-9a-f]{16}\b",
    "actual signing team assignment": r"(?m)^\s*DEVELOPMENT_TEAM\s*=\s*[A-Z0-9]{10}\s*$",
}
PATTERNS = {kind: re.compile(rule) for kind, rule in RULES.items()}
EMAIL = re.compile(r"(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b")
PUBLIC_EMAIL = re.compile(r"(?:\d+\+)?[A-Za-z0-9-]+@users\.noreply\.github\.com")
APP_ICON_DIRECTORY = PurePosixPath("App/Assets.xcassets/AppIcon.appiconset")
DEMO_DIRECTORY = PurePosixPath("docs/demo")
DEMO_EMAIL_HOSTS = {"example.com", "example.net", "example.org"}
PNG_MAGIC = bytes.fromhex("89504e470d0a1a0a")
PNG_CHUNKS = {b"IHDR", b"PLTE", b"IDAT", b"IEND", b"tRNS", b"sRGB", b"gAMA", b"cHRM", b"pHYs"}


class GateError(Exception):
    pass


def git(root, *arguments):
    result = subprocess.run(
        ["git", "-C", str(root), *arguments], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        env={**os.environ, "GIT_NO_REPLACE_OBJECTS": "1"}, timeout=60,
    )
    if result.returncode:
        # Git diagnostics can contain private filenames or invalid ref values.
        raise GateError(f"git {arguments[0]} failed")
    return result.stdout


def private_path(path):
    parts = tuple(part.lower() for part in path.parts)
    if path == PurePosixPath("server/.env.example"):
        return False
    return (
        re.fullmatch(r"forge-(?:export|backup|recovery)[^.]*\.json", parts[-1])
        or any(part in PRIVATE_PARTS or part.startswith(".env") or part.endswith(PRIVATE_ENDINGS) for part in parts)
        or parts[-1] == "local.xcconfig"
        or parts[:2] == ("config", "generated")
    )


def approved_png(path):
    return (
        path.parent == APP_ICON_DIRECTORY
        and re.fullmatch(r"(?:Icon|Mac-(?:16|32|64|128|256|512|1024))\.png", path.name)
    ) or (path.parent == DEMO_DIRECTORY and re.fullmatch(r"[a-z0-9-]+\.png", path.name))


def valid_png(data):
    if not data.startswith(PNG_MAGIC):
        return False
    offset = len(PNG_MAGIC)
    seen_header, seen_pixels = False, False
    while offset + 12 <= len(data):
        length, kind = struct.unpack_from(">I4s", data, offset)
        end = offset + length + 12
        if end > len(data) or kind not in PNG_CHUNKS:
            return False
        payload_end = end - 4
        checksum = struct.unpack_from(">I", data, payload_end)[0]
        if zlib.crc32(data[offset + 4:payload_end]) != checksum:
            return False
        if not seen_header and (kind != b"IHDR" or length != 13):
            return False
        if kind == b"IHDR":
            if seen_header:
                return False
            seen_header = True
        if kind == b"IDAT":
            seen_pixels = True
        if kind == b"IEND":
            return length == 0 and end == len(data) and seen_pixels
        offset = end
    return False


def contains_private_email(value):
    for match in EMAIL.finditer(value):
        address = match.group(0)
        host = address.rsplit("@", 1)[1].lower()
        if host not in DEMO_EMAIL_HOSTS and not PUBLIC_EMAIL.fullmatch(address):
            return True
    return False


class Review:
    def __init__(self, root):
        self.root = root
        self.issues = set()
        self.checked_blobs = set()

    def report(self, scope, path, reason):
        label = str(path)
        if (
            any(pattern.search(label) for pattern in PATTERNS.values())
            or contains_private_email(label)
            or any(not char.isprintable() for char in label)
        ):
            label = "[redacted path]"
        self.issues.add((scope, label, reason))

    def check_text(self, scope, path, value):
        for reason, pattern in PATTERNS.items():
            if pattern.search(value):
                self.report(scope, path, reason)
        if contains_private_email(value):
            self.report(scope, path, "non-placeholder email")

    def check_file(self, scope, name, read, size, mode):
        path = PurePosixPath(name)
        self.check_text(scope, path, name)
        if path.is_absolute() or ".." in path.parts:
            self.report(scope, path, "unsafe pathname")
        elif private_path(path):
            self.report(scope, path, "private or generated filename")
        elif mode not in {b"100644", b"100755"}:
            self.report(scope, path, "symlink, Git link, or non-regular file")
        elif size() > MAX_FILE_BYTES:
            self.report(scope, path, "file exceeds review size limit")
        elif approved_png(path):
            if not valid_png(read()):
                self.report(scope, path, "PNG is malformed or contains non-allowlisted metadata")
        elif path.suffix not in TEXT_EXTENSIONS and path.name not in TEXT_FILENAMES:
            self.report(scope, path, "unapproved file type")
        else:
            try:
                content = read().decode("utf-8")
            except UnicodeDecodeError:
                self.report(scope, path, "expected UTF-8 text")
            else:
                if "\0" in content:
                    self.report(scope, path, "unexpected binary content")
                self.check_text(scope, path, content)

    def worktree(self):
        # Ignored local-only files are outside Git's proposed upload. Tracked
        # files are still considered even if they now match an ignore rule.
        filenames = git(self.root, "ls-files", "-z", "--cached", "--others", "--exclude-standard")
        for raw in sorted(set(filenames.split(b"\0")) - {b""}):
            name = os.fsdecode(raw)
            file = self.root / name
            if file.is_symlink() or not file.is_file():
                mode = b"unsafe"
            else:
                mode = b"100644"
            self.check_file("worktree", name, file.read_bytes, lambda: file.stat().st_size, mode)

    def metadata(self, kind, oid, data):
        scope = f"{kind} {oid[:12]}"
        value = data.decode("utf-8", errors="replace")
        self.check_text(scope, "metadata", value)
        header, _, _ = value.partition("\n\n")
        identities = ("author ", "committer ") if kind == "commit" else ("tagger ",)
        for field in identities:
            lines = [line for line in header.splitlines() if line.startswith(field)]
            match = re.fullmatch(r".+ <([^<>]+)> \d+ [+-]\d{4}", lines[0]) if len(lines) == 1 else None
            if not match or not PUBLIC_EMAIL.fullmatch(match.group(1)):
                self.report(scope, "metadata", f"{kind} metadata needs a public GitHub noreply identity")

    def history(self, refs):
        if git(self.root, "rev-parse", "--is-shallow-repository").strip() != b"false":
            raise GateError("cannot establish public history from a shallow checkout")
        commits = set()
        checked_tags = set()
        for ref in refs:
            self.check_text("ref", "ref metadata", ref)
            oid = git(self.root, "rev-parse", "--verify", "--end-of-options", ref).decode().strip()
            while git(self.root, "cat-file", "-t", oid).strip() == b"tag":
                if oid in checked_tags:
                    break
                checked_tags.add(oid)
                tag = git(self.root, "cat-file", "tag", oid)
                self.metadata("tag", oid, tag)
                oid = tag.splitlines()[0].split()[1].decode("ascii")
            commit = git(self.root, "rev-parse", "--verify", "--end-of-options", f"{ref}^{{commit}}").strip()
            commits.update(git(self.root, "rev-list", commit.decode()).decode().splitlines())

        for oid in sorted(commits):
            self.metadata("commit", oid, git(self.root, "cat-file", "commit", oid))
            entries = git(self.root, "ls-tree", "-r", "-z", oid).split(b"\0")
            for entry in filter(None, entries):
                header, raw_name = entry.split(b"\t", 1)
                mode, _, blob = header.split()
                name = os.fsdecode(raw_name)
                key = (name, mode, blob)
                if key in self.checked_blobs:
                    continue
                self.checked_blobs.add(key)
                self.check_file(
                    f"history {blob.decode()[:12]}", name,
                    lambda: git(self.root, "cat-file", "blob", blob.decode()),
                    lambda: int(git(self.root, "cat-file", "-s", blob.decode())),
                    mode,
                )
        return len(commits), len(checked_tags), len(self.checked_blobs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--ref", action="append", help="repeat for each published ref (default: HEAD)")
    parser.add_argument("--worktree-only", action="store_true", help="check a candidate before committing")
    parser.add_argument("--exact-refs", action="store_true", help="require a clean worktree and only the listed refs")
    options = parser.parse_args()
    if options.worktree_only and (options.ref or options.exact_refs):
        parser.error("--worktree-only cannot be combined with --ref or --exact-refs")
    if options.exact_refs and (
        not options.ref or any(not ref.startswith(("refs/heads/", "refs/tags/")) for ref in options.ref)
    ):
        parser.error("--exact-refs requires explicit refs/heads/... or refs/tags/... names")

    try:
        root = Path(os.fsdecode(git(options.repo, "rev-parse", "--show-toplevel").rstrip(b"\n")))
        review = Review(root)
        if options.exact_refs:
            actual = set(git(root, "for-each-ref", "--format=%(refname)").decode().splitlines())
            if actual != set(options.ref):
                raise GateError("unexpected Git refs or missing publication refs")
            if git(root, "status", "--porcelain=v1", "-z"):
                raise GateError("publication worktree is not clean")
        review.worktree()
        counts = None if options.worktree_only else review.history(options.ref or ["HEAD"])
    except (GateError, OSError, ValueError, subprocess.TimeoutExpired) as error:
        message = str(error) if isinstance(error, GateError) else type(error).__name__
        print(f"Public snapshot review could not finish: {message}.", file=sys.stderr)
        return 1
    if review.issues:
        for scope, label, reason in sorted(review.issues):
            print(f"{scope}: {label}: {reason}", file=sys.stderr)
        return 1
    print("Public snapshot pattern checks passed for the proposed worktree.")
    if counts:
        print(f"Checked {counts[0]} commits, {counts[1]} annotated tags, and {counts[2]} distinct historical file entries.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
