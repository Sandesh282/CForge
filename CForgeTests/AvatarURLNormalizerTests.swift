//
//  AvatarURLNormalizerTests.swift
//  CForgeTests
//

import Foundation
import Testing
@testable import CForge

struct AvatarURLNormalizerTests {

    @Test func nilInputReturnsNil() {
        #expect(normalizeAvatarURL(nil) == nil)
    }

    @Test func emptyStringReturnsNil() {
        #expect(normalizeAvatarURL("") == nil)
    }

    @Test func protocolRelativeURLGetsHTTPSScheme() {
        let url = normalizeAvatarURL("//userpic.codeforces.org/no-title.jpg")
        #expect(url?.absoluteString == "https://userpic.codeforces.org/no-title.jpg")
        #expect(url?.scheme == "https")
    }

    @Test func absoluteHTTPSURLPassesThroughUnchanged() {
        let url = normalizeAvatarURL("https://userpic.codeforces.org/12345/avatar.jpg")
        #expect(url?.absoluteString == "https://userpic.codeforces.org/12345/avatar.jpg")
    }

    @Test func plainHTTPURLIsPreservedNotUpgraded() {
        // Documents current behavior: http:// is passed through as-is.
        // App Transport Security will block the load at fetch time unless
        // the host is exempted; normalization does not silently rewrite it.
        let url = normalizeAvatarURL("http://userpic.codeforces.org/avatar.jpg")
        #expect(url?.scheme == "http")
    }
}
