/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation

internal class E2EConfig {
    private struct InfoPlistKey {
        static let clientToken      = "E2EDatadogClientToken"
        static let rumApplicationID = "E2ERUMApplicationID"
    }

    private static var bundle: Bundle { Bundle(for: E2EConfig.self) }

    // MARK: - Info.plist

    static func readClientToken() -> String {
        guard let clientToken = bundle.infoDictionary?[InfoPlistKey.clientToken] as? String, !clientToken.isEmpty else {
            fatalError("""
            ✋⛔️ Cannot read `\(InfoPlistKey.clientToken)` from `Info.plist` dictionary.
            Update `xcconfigs/Datadog.xcconfig` with your own client token obtained on datadoghq.com.
            You might need to run `Product > Clean Build Folder` before retrying.
            """)
        }
        return clientToken
    }

    static func readRUMApplicationID() -> String {
        guard let rumApplicationID = bundle.infoDictionary![InfoPlistKey.rumApplicationID] as? String, !rumApplicationID.isEmpty else {
            fatalError("""
            ✋⛔️ Cannot read `\(InfoPlistKey.rumApplicationID)` from `Info.plist` dictionary.
            Update `xcconfigs/Datadog.xcconfig` with your own RUM application id obtained on datadoghq.com.
            You might need to run `Product > Clean Build Folder` before retrying.
            """)
        }
        return rumApplicationID
    }

    static func check() {
        _ = readClientToken()
        _ = readRUMApplicationID()
    }
}
