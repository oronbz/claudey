import XCTest

/// UI test bundles cannot use Swift Testing, and Claudey's window behavior —
/// layering, spaces, full-screen exclusion, focus preservation, dragging —
/// cannot be observed from a test process at all. It is checked by hand:
/// see docs/manual-verification.md. Automated coverage lives in ClaudeyTests.
final class ManualVerificationNotice: XCTestCase {}
