import XCTest

@MainActor final class ForgeUITests: XCTestCase {
    func launchFixture(_ app: XCUIApplication) {
        app.launch()
        #if os(macOS)
        app.activate()
        if !app.windows.firstMatch.waitForExistence(timeout:3) { app.typeKey("n", modifierFlags:.command) }
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout:10), "The actual fixture window must be created before workflow assertions")
        #endif
    }
    private func attachAppScreenshot(_ app: XCUIApplication, named name: String) {
        #if os(macOS)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists, "The screenshot requires the FORGE window")
        let screenshot = window.screenshot()
        #else
        let screenshot = app.screenshot()
        #endif
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func dashboard(_ app: XCUIApplication, _ field: String) -> XCUIElement {
        return app.staticTexts["dashboard.\(field)"]
    }
    func displayedText(_ element: XCUIElement) -> String {
        #if os(macOS)
        if let value = element.value as? String, !value.isEmpty { return value }
        #endif
        return element.label
    }
    func coinLabel(_ app: XCUIApplication) -> String {
        let label = displayedText(dashboard(app,"coins"))
        guard let range = label.range(of: #"\d+\s+Coins"#, options: .regularExpression) else { return label }
        return String(label[range])
    }
    func navigate(_ app:XCUIApplication,_ title:String) {
        #if os(macOS)
        app.staticTexts[title == "Home" ? "Command Center" : title].firstMatch.click()
        #else
        app.tabBars.buttons[title].tap()
        #endif
    }
    func reveal(_ element:XCUIElement,in app:XCUIApplication) {
        #if os(macOS)
        for _ in 0..<6 {
            if element.exists && element.isHittable { return }
            let scroll = app.sheets.scrollViews.firstMatch.exists ? app.sheets.scrollViews.firstMatch : app.scrollViews.firstMatch
            guard scroll.exists else { return }
            scroll.scroll(byDeltaX:0,deltaY:-250)
        }
        #else
        for _ in 0..<6 {
            if element.exists && element.isHittable { return }
            if app.collectionViews.firstMatch.exists && app.collectionViews.firstMatch.isHittable { app.collectionViews.firstMatch.swipeUp() }
            else { app.swipeUp() }
        }
        #endif
    }
    func press(_ element:XCUIElement) {
        #if os(macOS)
        element.click()
        #else
        element.tap()
        #endif
    }
    func testOnboardingAndEvidenceRewardLoop() {
        let app=XCUIApplication();app.launchArguments=["--ui-test", "--persistent-fixture", UUID().uuidString, "-forge.appearance", "Dark"];launchFixture(app)
        let enter=app.buttons["Enter the Command Center"]
        XCTAssertTrue(enter.waitForExistence(timeout:10));reveal(enter,in:app);press(enter)
        XCTAssertTrue(app.staticTexts["dashboard.mmr"].waitForExistence(timeout:5))
        XCTAssertEqual(displayedText(app.staticTexts["dashboard.mmr"]).filter(\.isNumber), "1000")
        XCTAssertTrue(dashboard(app,"rank").waitForExistence(timeout:5))
        XCTAssertTrue(displayedText(dashboard(app,"rank")).contains("BRONZE"))
        XCTAssertTrue(displayedText(dashboard(app,"level")).contains("LEVEL 1"))
        XCTAssertEqual(coinLabel(app),"0 Coins")
        attachAppScreenshot(app, named: "FORGE Command Center before completion")
        navigate(app,"Quests")
        for priority in ["main","secondary","supporting"] { XCTAssertTrue(app.buttons["quest.complete.\(priority)"].firstMatch.exists) }
        let main=app.buttons["quest.complete.main"].firstMatch;reveal(main,in:app);press(main)
        let proof=app.descendants(matching:.any).matching(identifier:"quest.evidence").firstMatch
        XCTAssertTrue(proof.waitForExistence(timeout:5));press(proof);proof.typeText("Contacted ten qualified buyers with specific workflow offers.")
        if app.buttons["Hide keyboard"].exists { press(app.buttons["Hide keyboard"]) }
        let claim=app.buttons["Record result & claim rewards"];reveal(claim,in:app);press(claim)
        XCTAssertTrue(claim.waitForNonExistence(timeout:10))
        let completed=app.buttons["quest.complete.main"].firstMatch
        XCTAssertTrue(completed.waitForExistence(timeout:5))
        let recorded=XCTNSPredicateExpectation(predicate:NSPredicate(format:"enabled == false"),object:completed)
        XCTAssertEqual(XCTWaiter.wait(for:[recorded],timeout:10),.completed)
        navigate(app,"Progress");XCTAssertTrue(app.staticTexts["Progress you can prove."].waitForExistence(timeout:5))
        let history = app.staticTexts["TRANSACTION HISTORY"]; reveal(history,in:app); XCTAssertTrue(history.exists)
        navigate(app,"Skills");XCTAssertTrue(app.staticTexts["Earn your expertise."].waitForExistence(timeout:5))
        navigate(app,"Home")
        #if !os(macOS)
        for _ in 0..<5 where !app.staticTexts["dashboard.mmr"].isHittable { app.swipeDown() }
        #endif
        XCTAssertNotEqual(coinLabel(app),"0 Coins")
        XCTAssertGreaterThan(Int(displayedText(app.staticTexts["dashboard.mmr"]).filter(\.isNumber)) ?? 0,1000)
        XCTAssertFalse(displayedText(dashboard(app,"level")).contains("· 0 /"))
        attachAppScreenshot(app, named: "FORGE Command Center after completion")
        let earnedCoins=coinLabel(app)
        app.terminate();launchFixture(app)
        XCTAssertTrue(app.staticTexts["dashboard.mmr"].waitForExistence(timeout:10))
        XCTAssertFalse(app.buttons["Enter the Command Center"].exists)
        XCTAssertEqual(coinLabel(app),earnedCoins)
        attachAppScreenshot(app, named: "FORGE Command Center after relaunch")
    }
    func testRevenueReviewRecoveryAndOfflineNavigation() {
        let app=XCUIApplication();app.launchArguments=["--ui-test"];launchFixture(app)
        press(app.buttons["Enter the Command Center"])
        let payment=app.buttons["Record payment"].firstMatch;reveal(payment,in:app);press(payment)
        let amount=app.textFields["revenue.amount"],client=app.textFields["revenue.client"]
        XCTAssertTrue(amount.waitForExistence(timeout:5));press(amount)
        #if os(macOS)
        amount.typeKey("a",modifierFlags:.command)
        #else
        amount.press(forDuration:1);if app.menuItems["Select All"].exists { app.menuItems["Select All"].tap() }
        #endif
        amount.typeText("150000");press(client);client.typeText("Acceptance customer")
        #if !os(macOS)
        app.swipeUp()
        #endif
        let record=app.buttons["revenue.record"];reveal(record,in:app);press(record)
        XCTAssertTrue(client.waitForNonExistence(timeout:10))
        let business = app.buttons["business.open"]; reveal(business,in:app); press(business)
        XCTAssertTrue(app.staticTexts["Value, validated."].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@ OR value CONTAINS %@", "150", "150")).firstMatch.exists)
        press(app.buttons["Done"].firstMatch)
        let review=app.buttons["Daily review"];reveal(review,in:app)
        #if !os(macOS)
        for _ in 0..<6 where !review.isHittable { app.swipeDown() }
        #endif
        press(review);let saveReview=app.buttons["Save review"];XCTAssertTrue(saveReview.waitForExistence(timeout:5));reveal(saveReview,in:app);press(saveReview)
        XCTAssertTrue(saveReview.waitForNonExistence(timeout:10))
        let recovery=app.buttons["Enter recovery"];reveal(recovery,in:app);press(recovery)
        navigate(app,"Quests");XCTAssertTrue(app.staticTexts["Send one qualified prospect a specific offer"].waitForExistence(timeout:5))
        navigate(app,"Progress");navigate(app,"Skills");navigate(app,"Settings")
        XCTAssertTrue(app.staticTexts["Settings"].firstMatch.waitForExistence(timeout:5))
        attachAppScreenshot(app, named: "FORGE offline secondary workflows")
    }
    func testSkillEvidenceAndLargeTextLightAppearance() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test", "-forge.appearance", "Light"]
        #if !os(macOS)
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        #endif
        launchFixture(app); let enter = app.buttons["Enter the Command Center"]; XCTAssertTrue(enter.waitForExistence(timeout:10)); reveal(enter,in:app); press(enter)
        navigate(app,"Skills"); let skill = app.buttons["skill.open.Python foundations"]; reveal(skill,in:app); press(skill)
        #if os(macOS)
        let selector = app.popUpButtons["skill.state"]
        #else
        let selector = app.buttons["skill.state"]
        #endif
        reveal(selector,in:app); XCTAssertTrue(selector.waitForExistence(timeout:5)); press(selector)
        #if os(macOS)
        press(app.menuItems["Practicing"])
        #else
        press(app.buttons["Practicing"].firstMatch)
        #endif
        let proof = app.descendants(matching:.any).matching(identifier:"skill.evidence").firstMatch; reveal(proof,in:app); press(proof); proof.typeText("Implemented and tested an independent typed Python script.")
        let save = app.buttons["Save progress"]; reveal(save,in:app); press(save); XCTAssertTrue(save.waitForNonExistence(timeout:10))
        reveal(skill,in:app); press(skill)
        #if !os(macOS)
        XCTAssertTrue(app.navigationBars["Skill evidence"].waitForExistence(timeout:5))
        #endif
        reveal(selector,in:app); XCTAssertTrue(selector.waitForExistence(timeout:5)); XCTAssertTrue(displayedText(selector).contains("Practicing"))
        attachAppScreenshot(app, named: "FORGE light appearance skill evidence")
    }
    func testNativeEditorDiagnosticControl() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test", "--native-editor-probe"]; launchFixture(app)
        let editor = app.descendants(matching:.any).matching(identifier:"native.editor").firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout:10)); press(editor); editor.typeText("Native SwiftUI control without FORGE layout.")
        XCTAssertTrue(editor.exists)
    }
}
