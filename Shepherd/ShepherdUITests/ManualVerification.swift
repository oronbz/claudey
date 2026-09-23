import XCTest

/// UI test bundles cannot use Swift Testing, and Shepherd's window behavior
/// cannot be observed from a test process at all. Hand checks live in
/// docs/manual-verification.md; automated coverage lives in ShepherdTests.
final class ManualVerificationNotice: XCTestCase {}
