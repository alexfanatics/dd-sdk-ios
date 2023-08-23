/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import XCTest
import TestUtilities
import DatadogInternal

@testable import DatadogCore

class MessageBusTests: XCTestCase {
    func testMessageBus() throws {
        let expectation = XCTestExpectation(description: "dispatch message")
        expectation.expectedFulfillmentCount = 2

        // Given
        let core = PassthroughCoreMock()

        let receiver = FeatureMessageReceiverMock(expectation: expectation) { message in
            // Then
            if let value: String = try? message.baggage(forKey: "test") {
                XCTAssertEqual(value, "value")
                expectation.fulfill()
            } else {
                XCTFail("wrong message case")
            }
        }

        let bus = MessageBus()
        bus.connect(core: core)

        bus.connect(receiver, forKey: "receiver 1")
        bus.connect(receiver, forKey: "receiver 2")

        // When
        try bus.send(message: .baggage(key: "test", value: "value"))

        // Then
        wait(for: [expectation], timeout: 0.5)
        bus.flush()
    }

    func testItForwardConfigurationAfterDispatch() throws {
        let expectation = XCTestExpectation(description: "dispatch configuration")
        let receiver = FeatureMessageReceiverMock(expectation: expectation) { message in
            guard
                case .telemetry(let telemetry) = message,
                case .configuration(let configuration) = telemetry
            else {
                return XCTFail("Message bus should send configuration telemetry")
            }

            XCTAssertEqual(configuration.batchSize, 1)
            XCTAssertTrue(configuration.trackErrors ?? false)
            expectation.fulfill()
        }

        // Given
        let core = PassthroughCoreMock()
        let bus = MessageBus(configurationDispatchTime: .milliseconds(90))
        bus.connect(core: core)
        bus.connect(receiver, forKey: "test")

        // When
        bus.configuration(batchSize: 1)
        bus.configuration(trackErrors: true)

        // Then
        wait(for: [expectation], timeout: 0.5)
        bus.flush()
    }
}

extension MessageBus: Telemetry {
    public func send(telemetry: DatadogInternal.TelemetryMessage) {
        send(message: .telemetry(telemetry))
    }
}
