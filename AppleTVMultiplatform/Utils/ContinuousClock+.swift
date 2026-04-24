import Foundation

nonisolated struct TimedResult<T: Sendable>: Sendable {
    let result: T
    let duration: Duration
    
    var seconds: Double {
        let (seconds, attoseconds) = duration.components
        return Double(seconds) + Double(attoseconds) / 1e18
    }
    
    var milliseconds: Double {
        seconds * 1000
    }
}

nonisolated func measureTime<T: Sendable>(_ operation: () throws -> T) rethrows -> TimedResult<T> {
    let clock = ContinuousClock()
    var result: T!
    let duration = try clock.measure {
        result = try operation()
    }
    return TimedResult(result: result, duration: duration)
}

nonisolated func measureTime<T: Sendable>(_ operation: @Sendable () async throws -> T) async rethrows -> TimedResult<T> {
    let clock = ContinuousClock()
    var result: T!
    let duration = try await clock.measure {
        result = try await operation()
    }
    return TimedResult(result: result, duration: duration)
}
