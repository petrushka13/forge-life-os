"""Verify account-independent signing settings in a temporary source copy."""

import json
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
TEAM = "AUDIT00001"
BUNDLE = "com.example.ForgeAudit"


class SigningConfigurationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixture = tempfile.TemporaryDirectory(prefix="forge-signing-")
        cls.addClassCleanup(fixture.cleanup)
        cls.root = Path(fixture.name)
        for directory in ("App", "Config", "FORGE.xcodeproj", "Integrations/ScreenTime", "Sources", "Tests", "UITests"):
            shutil.copytree(
                ROOT / directory,
                cls.root / directory,
                ignore=shutil.ignore_patterns("Local.xcconfig", "Generated", "xcuserdata"),
            )
        shutil.copy2(ROOT / "Package.swift", cls.root / "Package.swift")
        (cls.root / "scripts").mkdir()
        for script in ("configure_capabilities.py", "generate_project.py"):
            shutil.copy2(ROOT / "scripts" / script, cls.root / "scripts" / script)

        local_config = cls.root / "Config/Local.xcconfig"
        local_config.write_text("OTHER_SWIFT_FLAGS = -D AUDIT_FIXTURE\n")
        configure = [
            sys.executable, "scripts/configure_capabilities.py",
            "--team", TEAM, "--bundle", BUNDLE, "--health", "--cloud",
            "--container", "iCloud.com.example.ForgeAudit", "--screen-time",
            "--app-group", "group.com.example.ForgeAudit",
        ]
        subprocess.run(configure, cwd=cls.root, check=True, capture_output=True, timeout=30)
        generated_configuration = local_config.read_bytes()
        subprocess.run(
            [sys.executable, "scripts/generate_project.py"], cwd=cls.root, check=True,
            capture_output=True, timeout=30,
        )
        cls.local_config = local_config.read_bytes()
        cls.expected_config = generated_configuration

    def settings(self, sdk, configuration, *arguments):
        result = subprocess.run(
            ["xcodebuild", "-project", "FORGE.xcodeproj", "-alltargets", "-sdk", sdk,
             "-configuration", configuration, "-showBuildSettings", "-json", *arguments],
            cwd=self.root, capture_output=True, text=True, timeout=120,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return {
            entry["target"]: entry["buildSettings"]
            for entry in json.loads(result.stdout)
            if entry.get("target") in {"FORGE", "FORGEUITests", "ForgeMonitor", "ForgeReport"}
        }

    def assert_bundle_ids(self, settings, stem):
        self.assertEqual(settings["FORGE"]["PRODUCT_BUNDLE_IDENTIFIER"], stem)
        for target, suffix in (
            ("FORGEUITests", "UITests"), ("ForgeMonitor", "monitor"), ("ForgeReport", "report"),
        ):
            self.assertEqual(settings[target]["PRODUCT_BUNDLE_IDENTIFIER"], f"{stem}.{suffix}")

    def test_generated_account_configuration_survives_project_regeneration(self):
        self.assertEqual(self.local_config, self.expected_config)
        self.assertIn(b"OTHER_SWIFT_FLAGS = -D AUDIT_FIXTURE", self.local_config)
        for configuration in ("Debug", "Release"):
            with self.subTest(configuration=configuration):
                settings = self.settings("iphoneos", configuration)
                self.assert_bundle_ids(settings, BUNDLE)
                for target in ("FORGE", "FORGEUITests", "ForgeMonitor", "ForgeReport"):
                    self.assertEqual(settings[target]["DEVELOPMENT_TEAM"], TEAM)
                for target, path in (
                    ("FORGE", "iOS"), ("ForgeMonitor", "Monitor"), ("ForgeReport", "Report"),
                ):
                    self.assertEqual(settings[target]["CODE_SIGN_ENTITLEMENTS"], f"Config/Generated/{path}.entitlements")
                flags = settings["FORGE"]["SWIFT_ACTIVE_COMPILATION_CONDITIONS"].split()
                self.assertTrue({"FORGE_HEALTH_ENABLED", "FORGE_CLOUD_ENABLED", "FORGE_SCREEN_TIME_ENABLED"}.issubset(flags))

    def test_command_line_fixture_id_covers_app_and_extensions(self):
        settings = self.settings("iphonesimulator", "Debug", "FORGE_APP_BUNDLE_ID=com.example.ForgeFixture")
        self.assert_bundle_ids(settings, "com.example.ForgeFixture")

    def test_legacy_prefix_remains_usable_without_regenerating_local_account_settings(self):
        local = self.root / "Config/Local.xcconfig"
        original = local.read_bytes()
        self.addCleanup(local.write_bytes, original)
        local.write_text(
            "DEVELOPMENT_TEAM = AUDIT00001\n"
            "PRODUCT_BUNDLE_IDENTIFIER = com.example.Legacy\n"
            "FORGE_BUNDLE_PREFIX = com.example.Legacy\n"
        )
        self.assert_bundle_ids(self.settings("iphoneos", "Debug"), "com.example.Legacy")

    def test_cloudkit_configuration_resolves_mac_entitlements(self):
        settings = self.settings("macosx", "Release")["FORGE"]
        self.assertEqual(settings["PRODUCT_BUNDLE_IDENTIFIER"], BUNDLE)
        self.assertEqual(settings["DEVELOPMENT_TEAM"], TEAM)
        self.assertEqual(settings["CODE_SIGN_ENTITLEMENTS"], "Config/Generated/Mac.entitlements")
        self.assertIn("FORGE_CLOUD_ENABLED", settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"].split())

    def test_both_cloudkit_entitlement_files_extend_baseline_mac_permissions(self):
        baseline = plistlib.loads((self.root / "App/ForgeMac.entitlements").read_bytes())
        for filename, container in (
            ("Config/Generated/Mac.entitlements", "iCloud.com.example.ForgeAudit"),
            ("Config/MacOptional.entitlements", "$(FORGE_CLOUD_CONTAINER)"),
        ):
            with self.subTest(filename=filename):
                actual = plistlib.loads((self.root / filename).read_bytes())
                self.assertEqual({key: actual.get(key) for key in baseline}, baseline)
                self.assertEqual(actual["com.apple.developer.icloud-container-identifiers"], [container])
                self.assertEqual(actual["com.apple.developer.icloud-services"], ["CloudKit"])

    def test_optional_ios_entitlements_are_scoped_to_each_target(self):
        def entitlement(name):
            return plistlib.loads((self.root / f"Config/Generated/{name}.entitlements").read_bytes())

        app, monitor, report = (entitlement(name) for name in ("iOS", "Monitor", "Report"))
        self.assertTrue(app["com.apple.developer.healthkit"])
        self.assertEqual(app["com.apple.developer.icloud-container-identifiers"], ["iCloud.com.example.ForgeAudit"])
        for bundle_entitlements in (app, monitor, report):
            self.assertTrue(bundle_entitlements["com.apple.developer.family-controls"])
        group = ["group.com.example.ForgeAudit"]
        self.assertEqual(app["com.apple.security.application-groups"], group)
        self.assertEqual(monitor["com.apple.security.application-groups"], group)
        self.assertNotIn("com.apple.security.application-groups", report)


if __name__ == "__main__":
    unittest.main()
