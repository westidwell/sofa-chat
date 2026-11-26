import XCTest
@testable import SofaChatCore

final class ProTests: XCTestCase {
    func testProLinkAndPriceLiveInOnePlace() {
        XCTAssertEqual(PRO_URL, "https://github.com/westidwell/sofa-chat/blob/main/PRO.md")
        XCTAssertEqual(PRO_PRICE, "$1/month")
    }

    func testSixFeaturesWithNamesAndSummaries() {
        XCTAssertEqual(ProFeature.allCases.count, 6)
        for feature in ProFeature.allCases {
            XCTAssertFalse(feature.name.isEmpty)
            XCTAssertFalse(feature.summary.isEmpty)
            XCTAssertEqual(feature.id, feature.rawValue)
        }
    }

    func testLockedMessageWording() {
        for feature in ProFeature.allCases {
            XCTAssertEqual(
                feature.lockedMessage,
                "\(feature.name) is part of Pro ($1/month, not open yet): see PRO.md"
            )
        }
    }

    func testEveryStubThrowsItsOwnFeature() {
        func expect(_ feature: ProFeature, _ call: () throws -> Void, file: StaticString = #filePath, line: UInt = #line) {
            XCTAssertThrowsError(try call(), file: file, line: line) { error in
                let locked = error as? ProFeatureLocked
                XCTAssertEqual(locked?.feature, feature, file: file, line: line)
                XCTAssertEqual(locked?.url, PRO_URL, file: file, line: line)
                XCTAssertEqual(locked?.message, feature.lockedMessage, file: file, line: line)
                XCTAssertEqual(error.localizedDescription, feature.lockedMessage, file: file, line: line)
            }
        }
        expect(.handsFree) { try Pro.startHandsFreeMode() }
        expect(.familyProfiles) { try Pro.switchProfile(to: "Guest") }
        expect(.whatsPlaying) { _ = try Pro.askAboutWhatsPlaying("Who is that?") }
        expect(.phoneSharing) { _ = try Pro.receiveFromPhone(deviceName: "Test Phone") }
        expect(.longTermMemory) { try Pro.remember("The dog is named Biscuit.") }
        expect(.voiceChoices) { try Pro.setVoice(identifier: "test-voice") }
    }

    func testNothingClaimsProIsAvailable() {
        for feature in ProFeature.allCases {
            let text = (feature.summary + " " + feature.lockedMessage).lowercased()
            XCTAssertFalse(text.contains("available now"))
            XCTAssertFalse(text.contains("already built"))
            XCTAssertTrue(feature.lockedMessage.contains("not open yet"))
        }
    }

    /// PRO.md (at the repo root) must list every feature the app shows as locked.
    func testProDocListsEveryFeature() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // SofaChatCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // SofaChatCore
            .deletingLastPathComponent() // repo root
        let doc = try String(contentsOf: repoRoot.appendingPathComponent("PRO.md"), encoding: .utf8)
        XCTAssertTrue(doc.hasPrefix("Pro is $1/month (launch price). It isn't open yet: star or watch this repo to hear when it opens."))
        for feature in ProFeature.allCases {
            XCTAssertTrue(doc.contains(feature.name), "PRO.md is missing \(feature.name)")
        }
    }
}
