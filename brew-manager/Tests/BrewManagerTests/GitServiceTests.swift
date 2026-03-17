import XCTest
@testable import BrewManager

final class GitServiceTests: XCTestCase {

    // MARK: - Hash Validation (tested via diffBetween which calls validateHash)

    func testValidHashShort() async throws {
        // 7-char short hash — valid format, will fail at git level but passes validation
        // We test that validation doesn't throw for valid-looking hashes
        let service = GitService.shared
        // Use diffBetween which validates both hashes
        // These are valid hex strings but won't exist in the repo — that's fine,
        // we're testing that validateHash doesn't reject them before git runs
        do {
            _ = try await service.diffBetween(oldHash: "abcd1234", newHash: "efab5678")
        } catch let error as ProcessError {
            // Expected: git will fail because these commits don't exist
            // But we should NOT get a GitError.invalidHash
            XCTAssertTrue(error.localizedDescription.contains("git"))
        } catch let error as GitError {
            XCTFail("Should not get invalidHash for valid hex strings: \(error)")
        }
    }

    func testInvalidHashNonHex() async {
        let service = GitService.shared
        do {
            _ = try await service.diffBetween(oldHash: "xyz12345", newHash: "abcd1234")
            XCTFail("Should throw for non-hex characters")
        } catch let error as GitError {
            if case .invalidHash(let hash) = error {
                XCTAssertEqual(hash, "xyz12345")
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testInvalidHashTooShort() async {
        let service = GitService.shared
        do {
            _ = try await service.diffBetween(oldHash: "abc", newHash: "abcd1234")
            XCTFail("Should throw for hash shorter than 4 chars")
        } catch let error as GitError {
            if case .invalidHash(let hash) = error {
                XCTAssertEqual(hash, "abc")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testInvalidHashEmpty() async {
        let service = GitService.shared
        do {
            _ = try await service.diffBetween(oldHash: "", newHash: "abcd1234")
            XCTFail("Should throw for empty hash")
        } catch is GitError {
            // Expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testInvalidHashInjection() async {
        // Attempt shell injection via hash parameter
        let service = GitService.shared
        do {
            _ = try await service.diffBetween(oldHash: "abcd; rm -rf /", newHash: "abcd1234")
            XCTFail("Should throw for hash with special characters")
        } catch is GitError {
            // Expected — blocked by validation
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testInvalidHashTooLong() async {
        let service = GitService.shared
        let longHash = String(repeating: "a", count: 41)
        do {
            _ = try await service.diffBetween(oldHash: longHash, newHash: "abcd1234")
            XCTFail("Should throw for hash longer than 40 chars")
        } catch is GitError {
            // Expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testValidHash40Chars() async {
        // Full 40-char SHA should pass validation
        let service = GitService.shared
        let fullHash = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
        do {
            _ = try await service.diffBetween(oldHash: fullHash, newHash: "abcd1234")
        } catch is GitError {
            XCTFail("40-char hex hash should pass validation")
        } catch {
            // ProcessError is fine — means validation passed but git failed (expected)
        }
    }

    func testValidHash4Chars() async {
        // Minimum 4-char hash should pass validation
        let service = GitService.shared
        do {
            _ = try await service.diffBetween(oldHash: "abcd", newHash: "ef01")
        } catch is GitError {
            XCTFail("4-char hex hash should pass validation")
        } catch {
            // ProcessError is fine
        }
    }

    // MARK: - GitError description

    func testGitErrorDescription() {
        let error = GitError.invalidHash("bad!hash")
        XCTAssertTrue(error.localizedDescription.contains("bad!hash"))
        XCTAssertTrue(error.localizedDescription.contains("hexadecimal"))
    }
}
