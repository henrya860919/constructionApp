//
//  FieldNetworkMonitor.swift
//  constructionApp
//

import Foundation
import Network
import Observation

@MainActor
@Observable
final class FieldNetworkMonitor {
    static let shared = FieldNetworkMonitor()

    private(set) var isReachable = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "FieldNetworkMonitor")

    private init() {
        monitor.pathUpdateHandler = { path in
            let ok = path.status == .satisfied
            Task { @MainActor in
                FieldNetworkMonitor.shared.isReachable = ok
            }
        }
        monitor.start(queue: queue)
        isReachable = monitor.currentPath.status == .satisfied
    }
}
