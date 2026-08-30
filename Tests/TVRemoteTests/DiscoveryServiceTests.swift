import Network
import XCTest
@testable import TVRemote

final class DiscoveryServiceTests: XCTestCase {
    func testServiceNameExtractedFromServiceEndpoint() {
        let endpoint = NWEndpoint.service(
            name: "Living Room TV",
            type: DiscoveryService.serviceType,
            domain: DiscoveryService.domain,
            interface: nil
        )
        XCTAssertEqual(DiscoveryService.serviceName(from: endpoint), "Living Room TV")
    }

    func testServiceNameIsNilForHostPortEndpoint() {
        let endpoint = NWEndpoint.hostPort(host: "192.168.1.40", port: 6466)
        XCTAssertNil(DiscoveryService.serviceName(from: endpoint))
    }

    func testPolicyDeniedIsRecognisedAsPermissionDenial() {
        let denied = NWError.dns(DNSServiceErrorType(kDNSServiceErr_PolicyDenied))
        XCTAssertTrue(DiscoveryService.isPermissionDenied(denied))
    }

    func testOtherDNSErrorsAreNotPermissionDenial() {
        let noSuchRecord = NWError.dns(DNSServiceErrorType(kDNSServiceErr_NoSuchRecord))
        XCTAssertFalse(DiscoveryService.isPermissionDenied(noSuchRecord))
        XCTAssertFalse(DiscoveryService.isPermissionDenied(.posix(.ECONNREFUSED)))
    }

    @MainActor
    func testPersistsServiceInstanceNameNotAddress() {
        let defaults = UserDefaults(suiteName: "DiscoveryServiceTests")!
        defaults.removePersistentDomain(forName: "DiscoveryServiceTests")
        let service = DiscoveryService(defaults: defaults)

        let tv = DiscoveredTV(
            serviceName: "Living Room TV",
            endpoint: .service(
                name: "Living Room TV",
                type: DiscoveryService.serviceType,
                domain: DiscoveryService.domain,
                interface: nil
            ),
            host: "192.168.1.40",
            port: 6466
        )
        service.remember(tv)

        XCTAssertEqual(service.lastKnownServiceName, "Living Room TV")
        let stored = defaults.string(forKey: DiscoveryService.lastKnownDefaultsKey)
        XCTAssertEqual(stored, "Living Room TV")
        XCTAssertFalse(stored?.contains("192.168") ?? false)
    }

    @MainActor
    func testEndpointRebuiltFromRememberedName() {
        let defaults = UserDefaults(suiteName: "DiscoveryServiceTests")!
        let service = DiscoveryService(defaults: defaults)
        let endpoint = service.endpoint(forServiceNamed: "Living Room TV")
        guard case let .service(name, type, domain, _) = endpoint else {
            return XCTFail("expected a service endpoint")
        }
        XCTAssertEqual(name, "Living Room TV")
        XCTAssertEqual(type, "_androidtvremote2._tcp")
        XCTAssertEqual(domain, "local.")
    }
}
