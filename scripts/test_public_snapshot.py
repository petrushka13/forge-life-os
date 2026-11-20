"""Exercise the publication gate with synthetic local repositories."""

from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib

CHECKER = Path(__file__).with_name("check_public_snapshot.py").resolve()
STRIPPER = CHECKER.with_name("strip_png_metadata.py")
IDENTITY = "portfolio@users.noreply.github.com"


def png_chunk(kind, payload):
    body = kind + payload
    return struct.pack(">I", len(payload)) + body + struct.pack(">I", zlib.crc32(body))


def one_pixel_png():
    header = struct.pack(">IIBBBBB", 1, 1, 8, 0, 0, 0, 0)
    return (
        bytes.fromhex("89504e470d0a1a0a")
        + png_chunk(b"IHDR", header)
        + png_chunk(b"IDAT", zlib.compress(b"\x00\xff"))
        + png_chunk(b"IEND", b"")
    )


class PublicSnapshotTests(unittest.TestCase):
    def setUp(self):
        workspace = tempfile.TemporaryDirectory(prefix="forge-public-test-")
        self.addCleanup(workspace.cleanup)
        self.root = Path(workspace.name)
        self.git("init", "-b", "main", "-q")
        self.git("config", "user.name", "Portfolio")
        self.git("config", "user.email", IDENTITY)
        self.write("README.md", b"# Synthetic example\n")
        self.commit()

    def git(self, *arguments):
        return subprocess.run(
            ["git", *arguments], cwd=self.root, capture_output=True, check=True,
        )

    def write(self, name, data):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def commit(self):
        self.git("add", "-A")
        self.git("-c", "commit.gpgsign=false", "commit", "-qm", "Synthetic example")

    def check(self, *arguments):
        result = subprocess.run(
            [sys.executable, str(CHECKER), *arguments], cwd=self.root,
            capture_output=True, text=True, timeout=30,
        )
        return result.returncode, result.stdout + result.stderr

    def test_clean_public_tree_and_refs_pass(self):
        self.git("tag", "v1.0.0")
        code, output = self.check("--exact-refs", "--ref", "refs/heads/main", "--ref", "refs/tags/v1.0.0")
        self.assertEqual(code, 0, output)

    def test_unreviewed_refs_are_rejected_in_exact_mode(self):
        self.git("branch", "unreviewed")
        code, output = self.check("--exact-refs", "--ref", "refs/heads/main")
        self.assertEqual(code, 1)
        self.assertIn("unexpected Git refs", output)

    def test_secret_removed_from_tip_still_fails_history_check(self):
        secret = "gh" + "p_" + "AB123" * 8
        self.write("notes.txt", secret.encode())
        self.commit()
        (self.root / "notes.txt").unlink()
        self.commit()
        code, output = self.check()
        self.assertEqual(code, 1)
        self.assertIn("GitHub token", output)
        self.assertNotIn(secret, output)

    def test_private_identity_in_commit_metadata_is_rejected(self):
        self.git("config", "user.email", "developer@" + "workstation.local")
        self.write("README.md", b"# Another synthetic example\n")
        self.commit()
        code, output = self.check()
        self.assertEqual(code, 1)
        self.assertIn("commit metadata", output)
        self.assertNotIn("workstation.local", output)

    def test_local_files_and_paths_fail_worktree_check(self):
        self.write("README.md", ("Temporary evidence: /" + "Users/LocalPerson/log.txt").encode())
        self.write("Config/Local.xcconfig", b"DEVELOPMENT_TEAM = AUDIT00001\n")
        code, output = self.check("--worktree-only")
        self.assertEqual(code, 1)
        self.assertIn("workstation path", output)
        self.assertIn("private or generated filename", output)
        self.assertNotIn("LocalPerson", output)

    def test_png_metadata_is_rejected_and_removal_preserves_image_chunks(self):
        name = "docs/demo/command-center.png"
        png = one_pixel_png()
        chunk = png_chunk(b"tEXt", b"Comment\x00synthetic metadata") + png_chunk(b"iCCP", b"Synthetic profile\x00\x00" + zlib.compress(b"fake profile"))
        self.write(name, png[:-12] + chunk + png[-12:])
        code, output = self.check("--worktree-only")
        self.assertEqual(code, 1, output)
        self.assertIn("non-allowlisted metadata", output)
        result = subprocess.run(
            [sys.executable, "-B", str(STRIPPER), name], cwd=self.root,
            capture_output=True, text=True, timeout=30,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / name).read_bytes(), png)
        code, output = self.check("--worktree-only")
        self.assertEqual(code, 0, output)

    def test_private_annotated_tag_message_is_rejected(self):
        self.git("tag", "-a", "v1.0.0", "-m", "Contact reviewer@" + "private.example")
        code, output = self.check("--exact-refs", "--ref", "refs/heads/main", "--ref", "refs/tags/v1.0.0")
        self.assertEqual(code, 1, output)
        self.assertIn("non-placeholder email", output)
        self.assertNotIn("private.example", output)

    def test_unknown_binary_and_symlink_are_rejected(self):
        self.write("docs/sample.bin", b"\x00\xff")
        (self.root / "docs/link").symlink_to(self.root / "README.md")
        code, output = self.check("--worktree-only")
        self.assertEqual(code, 1)
        self.assertIn("unapproved file type", output)
        self.assertIn("symlink", output)


if __name__ == "__main__":
    unittest.main()
