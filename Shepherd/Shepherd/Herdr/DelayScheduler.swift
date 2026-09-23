import Foundation

protocol ScheduledWork: AnyObject {
    func cancel()
}

protocol DelayScheduler: AnyObject {
    func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) -> ScheduledWork
}

final class TimerScheduler: DelayScheduler {
    private final class Handle: ScheduledWork {
        let timer: Timer
        init(timer: Timer) { self.timer = timer }
        func cancel() { timer.invalidate() }
    }

    func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) -> ScheduledWork {
        let timer = Timer(timeInterval: max(delay, 0), repeats: false) { _ in
            MainActor.assumeIsolated { work() }
        }
        RunLoop.main.add(timer, forMode: .common)
        return Handle(timer: timer)
    }
}
