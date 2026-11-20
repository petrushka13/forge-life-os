# Native walkthrough

These captures come from the local XCTest acceptance suite running the real FORGE app with synthetic data. The test records a result, checks its transaction history and restarts the same isolated workspace.

1. [After onboarding](mac-before-completion.png). The Command Center starts with a 1,000 life rating, no earned XP or Coins, and three priorities.
2. [After recording a result](mac-after-completion.png). The completed quest shows its evidence, and the dashboard reflects the earned progression.
3. [After relaunch](mac-after-relaunch.png). The app reopens the same store, and the completion and earned balance are still present.

[iPhone Simulator skill evidence at the largest accessibility text size](iphone-skill-evidence.png) shows the separate save-and-reopen skill test. Mac captures are scoped to the FORGE window. Screenshot metadata was removed without changing the image content. The fixture profile is synthetic.

Reproduce on Mac with `bash scripts/verify_mac_ui.sh`. The script prints its temporary evidence directory. Use Xcode's Result Bundle viewer or `xcrun xcresulttool export attachments` to inspect the captures. To repeat the data-integrity demonstration without interacting with a native file picker, run `swift run ForgeDesktop --smoke-test`; the isolated smoke covers backup restore, a failed save, migration and recovery.
