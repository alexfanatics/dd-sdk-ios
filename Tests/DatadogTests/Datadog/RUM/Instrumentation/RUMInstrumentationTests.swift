/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import XCTest
@testable import Datadog

class RUMInstrumentationTests: XCTestCase {
    let core = DatadogCoreMock()

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        core.flush()
        super.tearDown()
    }

    func testGivenRUMViewsAutoInstrumentationEnabled_whenRUMMonitorIsRegistered_itSubscribesAsViewsHandler() throws {
        // Given
        let rum: RUMFeature = .mockNoOp()

        let instrumentation = RUMInstrumentation(
            configuration: .init(
                uiKitRUMViewsPredicate: UIKitRUMViewsPredicateMock(),
                uiKitRUMUserActionsPredicate: nil,
                longTaskThreshold: nil
            ),
            dateProvider: SystemDateProvider()
        )
        core.registerFeature(named: RUMFeature.featureName, instance: rum)
        core.register(feature: instrumentation)

        // When
        Global.rum = RUMMonitor.initialize(in: core)
        defer { Global.rum = DDNoopRUMMonitor() }

        // Then
        let viewsHandler = instrumentation.viewsHandler
        XCTAssertTrue(viewsHandler.subscriber === Global.rum)
    }

    func testGivenRUMUserActionsAutoInstrumentationEnabled_whenRUMMonitorIsRegistered_itSubscribesAsUserActionsHandler() throws {
        // Given
        let rum: RUMFeature = .mockNoOp()

        let instrumentation = RUMInstrumentation(
            configuration: .init(
                uiKitRUMViewsPredicate: nil,
                uiKitRUMUserActionsPredicate: UIKitRUMUserActionsPredicateMock(),
                longTaskThreshold: nil
            ),
            dateProvider: SystemDateProvider()
        )
        core.registerFeature(named: RUMFeature.featureName, instance: rum)
        core.register(feature: instrumentation)

        // When
        Global.rum = RUMMonitor.initialize(in: core)
        defer { Global.rum = DDNoopRUMMonitor() }

        // Then
        let userActionsHandler = instrumentation.userActionsAutoInstrumentation?.handler as? UIKitRUMUserActionsHandler
        XCTAssertTrue(userActionsHandler?.subscriber === Global.rum)
    }

    func testGivenRUMLongTasksAutoInstrumentationEnabled_whenRUMMonitorIsRegistered_itSubscribesAsLongTaskObserver() throws {
        // Given
        let rum: RUMFeature = .mockNoOp()
        let instrumentation = RUMInstrumentation(
            configuration: .init(
                uiKitRUMViewsPredicate: nil,
                uiKitRUMUserActionsPredicate: nil,
                longTaskThreshold: 100.0
            ),
            dateProvider: SystemDateProvider()
        )

        core.registerFeature(named: RUMFeature.featureName, instance: rum)
        core.register(feature: instrumentation)

        // When
        Global.rum = RUMMonitor.initialize(in: core)
        defer { Global.rum = DDNoopRUMMonitor() }

        // Then
        XCTAssertTrue(instrumentation.longTasks?.subscriber === Global.rum)
    }

    /// Sanity check for not-allowed configuration.
    func testWhenAllRUMAutoInstrumentationsDisabled_itDoesNotCreateInstrumentationComponents() throws {
        // Given
        let rum: RUMFeature = .mockNoOp()

        /// This configuration is not allowed by `FeaturesConfiguration` logic. We test it for sanity.
        let notAllowedConfiguration = FeaturesConfiguration.RUM.Instrumentation(
            uiKitRUMViewsPredicate: nil,
            uiKitRUMUserActionsPredicate: nil,
            longTaskThreshold: nil
        )

        let instrumentation = RUMInstrumentation(
            configuration: notAllowedConfiguration,
            dateProvider: SystemDateProvider()
        )

        core.registerFeature(named: RUMFeature.featureName, instance: rum)
        core.register(feature: instrumentation)

        // Then
        XCTAssertNil(instrumentation.viewControllerSwizzler)
        XCTAssertNil(instrumentation.userActionsAutoInstrumentation)
    }
}
