import XCTest
import TVRemoteCore
@testable import TVRemote

@MainActor
final class MacroServiceTests: XCTestCase {
    private func makeService() -> (MacroService, UserDefaults) {
        let suite = "MacroServiceTests"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (MacroService(defaults: defaults), defaults)
    }

    func testEndpointIsNilWhenBaseURLEmpty() {
        let (service, _) = makeService()
        XCTAssertNil(service.endpoint(for: Macro.all[0]))
    }

    func testEndpointBuiltFromBaseURL() {
        let (service, _) = makeService()
        service.baseURL = "http://192.168.1.10:8080"
        XCTAssertEqual(
            service.endpoint(for: Macro.all[0])?.absoluteString,
            "http://192.168.1.10:8080/macro/stream-pc"
        )
    }

    func testTrailingSlashDoesNotDoubleUp() {
        let (service, _) = makeService()
        service.baseURL = "http://host:8080/"
        XCTAssertEqual(
            service.endpoint(for: Macro.all[1])?.absoluteString,
            "http://host:8080/macro/xbox"
        )
    }

    func testUnconfiguredRunReportsMissingServer() async {
        let (service, _) = makeService()
        await service.run(Macro.all[0])
        XCTAssertEqual(service.state(for: Macro.all[0]), .failed("No server configured"))
    }

    func testExactlyOneAccentedMacro() {
        XCTAssertEqual(Macro.all.filter(\.accented).count, 1)
        XCTAssertEqual(Macro.all.first(where: \.accented)?.id, "stream-pc")
    }
}
