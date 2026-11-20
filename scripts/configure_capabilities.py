"""Write ignored personal signing overrides from the checked-in baseline entitlements."""

import argparse
from pathlib import Path
import plistlib
import re

PROJECT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--team", required=True)
    parser.add_argument("--bundle", required=True)
    parser.add_argument("--health", action="store_true")
    parser.add_argument("--cloud", action="store_true")
    parser.add_argument("--screen-time", action="store_true")
    parser.add_argument("--container")
    parser.add_argument("--app-group")
    parser.add_argument("--output-dir", type=Path, default=PROJECT / "Config")
    options = parser.parse_args()

    if not re.fullmatch(r"[A-Z0-9]{10}", options.team):
        parser.error("Team must be the ten-character Apple Team ID")
    for value in (options.bundle, options.container, options.app_group):
        if value is not None and not re.fullmatch(r"[A-Za-z0-9.-]+", value):
            parser.error("Identifiers may contain only letters, digits, dots and hyphens")
    if options.cloud and not (options.container or "").startswith("iCloud."):
        parser.error("--cloud requires the registered iCloud container")
    if options.screen_time and not (options.app_group or "").startswith("group."):
        parser.error("--screen-time requires the registered app group")

    ios = plistlib.loads((PROJECT / "Config/iOS.entitlements").read_bytes())
    mac = plistlib.loads((PROJECT / "App/ForgeMac.entitlements").read_bytes())
    extension_baseline = plistlib.loads((PROJECT / "Config/Extension.entitlements").read_bytes())
    monitor, report = extension_baseline.copy(), extension_baseline.copy()
    ios_flags, mac_flags = [], []

    if options.health:
        ios["com.apple.developer.healthkit"] = True
        ios_flags.append("FORGE_HEALTH_ENABLED")
    if options.cloud:
        for entitlements in (ios, mac):
            entitlements["com.apple.developer.icloud-container-identifiers"] = [options.container]
            entitlements["com.apple.developer.icloud-services"] = ["CloudKit"]
        ios_flags.append("FORGE_CLOUD_ENABLED")
        mac_flags.append("FORGE_CLOUD_ENABLED")
    if options.screen_time:
        for entitlements in (ios, monitor, report):
            entitlements["com.apple.developer.family-controls"] = True
        for entitlements in (ios, monitor):
            entitlements["com.apple.security.application-groups"] = [options.app_group]
        ios_flags.append("FORGE_SCREEN_TIME_ENABLED")

    config = options.output_dir
    generated = config / "Generated"
    generated.mkdir(parents=True, exist_ok=True)
    for name, data in (("iOS", ios), ("Mac", mac), ("Monitor", monitor), ("Report", report)):
        path = generated / f"{name}.entitlements"
        path.write_bytes(plistlib.dumps(data))
        path.chmod(0o600)

    managed = {
        "DEVELOPMENT_TEAM": options.team,
        "FORGE_APP_BUNDLE_ID": options.bundle,
        "FORGE_IOS_ENTITLEMENTS": "Config/Generated/iOS.entitlements",
        "FORGE_MAC_ENTITLEMENTS": "Config/Generated/Mac.entitlements",
        "FORGE_EXTENSION_ENTITLEMENTS": "Config/Generated/Monitor.entitlements",
        "FORGE_REPORT_ENTITLEMENTS": "Config/Generated/Report.entitlements",
        "FORGE_IOS_FLAGS": " ".join(ios_flags),
        "FORGE_MAC_FLAGS": " ".join(mac_flags),
        "FORGE_CLOUD_CONTAINER": options.container or "",
        "FORGE_APP_GROUP": options.app_group or "",
    }
    superseded = {"PRODUCT_BUNDLE_IDENTIFIER", "FORGE_BUNDLE_PREFIX"}
    local = config / "Local.xcconfig"
    previous = local.read_text().splitlines() if local.exists() else []
    preserved = [
        line for line in previous
        if line.split("=", 1)[0].strip() not in (managed.keys() | superseded)
    ]
    local.write_text("\n".join(preserved + [f"{key} = {value}" for key, value in managed.items()]) + "\n")
    local.chmod(0o600)
    print("Personal configuration written. Register the selected capabilities in Apple Developer/Xcode before signing. No account values were printed.")


if __name__ == "__main__":
    main()
