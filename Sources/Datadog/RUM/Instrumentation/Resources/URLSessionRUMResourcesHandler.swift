/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation
import DatadogInternal

internal struct DistributedTracing {
    /// Tracing sampler used to sample traces generated by the SDK.
    let sampler: Sampler
    /// The distributed tracing ID generator.
    let traceIDGenerator: TraceIDGenerator
    /// First party hosts defined by the user.
    let firstPartyHosts: FirstPartyHosts

    init(
        sampler: Sampler,
        firstPartyHosts: FirstPartyHosts,
        traceIDGenerator: TraceIDGenerator = DefaultTraceIDGenerator()
    ) {
        self.sampler = sampler
        self.traceIDGenerator = traceIDGenerator
        self.firstPartyHosts = firstPartyHosts
    }
}

internal final class URLSessionRUMResourcesHandler: DatadogURLSessionHandler, RUMCommandPublisher {
    /// The date provider
    let dateProvider: DateProvider
    /// DistributinTracing
    let distributedTracing: DistributedTracing?
    /// Attributes-providing callback.
    /// It is configured by the user and should be used to associate additional RUM attributes with intercepted RUM Resource.
    let rumAttributesProvider: URLSessionRUMAttributesProvider?

    /// First party hosts defined by the user.
    var firstPartyHosts: FirstPartyHosts {
        distributedTracing?.firstPartyHosts ?? .init()
    }

    // MARK: - Initialization

    init(
        dateProvider: DateProvider = SystemDateProvider(),
        rumAttributesProvider: URLSessionRUMAttributesProvider? = nil,
        distributedTracing: DistributedTracing? = nil
    ) {
        self.dateProvider = dateProvider
        self.rumAttributesProvider = rumAttributesProvider
        self.distributedTracing = distributedTracing
    }

    // MARK: - Internal

    weak var subscriber: RUMCommandSubscriber?

    func publish(to subscriber: RUMCommandSubscriber) {
        self.subscriber = subscriber
    }

    // MARK: - DatadogURLSessionHandler

    func modify(request: URLRequest, headerTypes: Set<DatadogInternal.TracingHeaderType>) -> URLRequest {
        distributedTracing?.modify(request: request, headerTypes: headerTypes) ?? request
    }

    func interceptionDidStart(interception: DatadogInternal.URLSessionTaskInterception) {
        let url = interception.request.url?.absoluteString ?? "unknown_url"
        interception.register(origin: "rum")

        subscriber?.process(
            command: RUMStartResourceCommand(
                resourceKey: interception.identifier.uuidString,
                time: dateProvider.now,
                attributes: [:],
                url: url,
                httpMethod: RUMMethod(httpMethod: interception.request.httpMethod),
                kind: RUMResourceType(request: interception.request),
                spanContext: distributedTracing?.trace(from: interception)
            )
        )
    }

    func interceptionDidComplete(interception: DatadogInternal.URLSessionTaskInterception) {
        guard let subscriber = subscriber else {
            return DD.logger.warn(
                """
                RUM Resource was completed, but no `RUMMonitor` is initiaized in the core. RUM auto instrumentation will not work.
                Make sure `RUMMonitor.initialize()` is called before any network request is send.
                """
            )
        }

        // Get RUM Resource attributes from the user.
        let userAttributes = rumAttributesProvider?(
            interception.request,
            interception.completion?.httpResponse,
            interception.data,
            interception.completion?.error
        ) ?? [:]

        if let resourceMetrics = interception.metrics {
            subscriber.process(
                command: RUMAddResourceMetricsCommand(
                    resourceKey: interception.identifier.uuidString,
                    time: dateProvider.now,
                    attributes: [:],
                    metrics: resourceMetrics
                )
            )
        }

        if let httpResponse = interception.completion?.httpResponse {
            subscriber.process(
                command: RUMStopResourceCommand(
                    resourceKey: interception.identifier.uuidString,
                    time: dateProvider.now,
                    attributes: userAttributes,
                    kind: RUMResourceType(response: httpResponse),
                    httpStatusCode: httpResponse.statusCode,
                    size: interception.metrics?.responseSize
                )
            )
        }

        if let error = interception.completion?.error {
            subscriber.process(
                command: RUMStopResourceWithErrorCommand(
                    resourceKey: interception.identifier.uuidString,
                    time: dateProvider.now,
                    error: error,
                    source: .network,
                    httpStatusCode: interception.completion?.httpResponse?.statusCode,
                    attributes: userAttributes
                )
            )
        }
    }
}

extension DistributedTracing {
    func modify(request: URLRequest, headerTypes: Set<DatadogInternal.TracingHeaderType>) -> URLRequest {
        let traceID = traceIDGenerator.generate()
        let spanID = traceIDGenerator.generate()

        var request = request
        // To make sure the generated traces from RUM don’t affect APM Index Spans counts.
        request.setValue("rum", forHTTPHeaderField: TracingHTTPHeaders.originField)

        headerTypes.forEach {
            let writer: TracePropagationHeadersWriter
            switch $0 {
            case .datadog:
                writer = HTTPHeadersWriter(sampler: sampler)
            case .b3:
                writer = OTelHTTPHeadersWriter(
                    sampler: sampler,
                    injectEncoding: .single
                )
            case .b3multi:
                writer = OTelHTTPHeadersWriter(
                    sampler: sampler,
                    injectEncoding: .multiple
                )
            case .tracecontext:
                writer = W3CHTTPHeadersWriter(sampler: sampler)
            }

            writer.write(
                traceID: traceID,
                spanID: spanID,
                parentSpanID: nil
            )

            writer.traceHeaderFields.forEach { field, value in
                request.setValue(value, forHTTPHeaderField: field)
            }
        }

        return request
    }

    func trace(from interception: DatadogInternal.URLSessionTaskInterception) -> RUMSpanContext? {
        return interception.trace.map {
           .init(
               traceID: String($0.traceID),
               spanID: String($0.spanID),
               samplingRate: Double(sampler.samplingRate) / 100.0
           )
        }
    }
}

private extension HTTPURLResponse {
    func asClientError() -> Error? {
        // 4xx Client Errors
        guard statusCode >= 400 && statusCode < 500 else {
            return nil
        }
        let message = "\(statusCode) " + HTTPURLResponse.localizedString(forStatusCode: statusCode)
        return NSError(domain: "HTTPURLResponse", code: statusCode, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
