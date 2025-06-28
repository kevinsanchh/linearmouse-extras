// MIT License
// Copyright (c) 2021-2024 LinearMouse

import Combine
import Defaults
import Foundation
import LRUCache
import os.log

class EventTransformerManager {
    static let shared = EventTransformerManager()
    static let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "EventTransformerManager")

    @Default(.bypassEventsFromOtherApplications) var bypassEventsFromOtherApplications

    private var eventTransformerCache = LRUCache<CacheKey, EventTransformer>(countLimit: 16)
    private var activeCacheKey: CacheKey?

    struct CacheKey: Hashable {
        var deviceMatcher: DeviceMatcher?
        var pid: pid_t?
        var screen: String?
    }

    private var subscriptions = Set<AnyCancellable>()

    init() {
        ConfigurationState.shared.$configuration
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.eventTransformerCache.removeAllValues()
            }
            .store(in: &subscriptions)
    }

    private let sourceBundleIdentifierBypassSet: Set<String> = [
        "cc.ffitch.shottr"
    ]

    func get(withCGEvent cgEvent: CGEvent,
             withSourcePid sourcePid: pid_t?,
             withTargetPid pid: pid_t?,
             withDisplay display: String?) -> EventTransformer {
        let prevActiveCacheKey = activeCacheKey
        defer {
            if let prevActiveCacheKey = prevActiveCacheKey,
               prevActiveCacheKey != activeCacheKey {
                if let eventTransformer = eventTransformerCache.value(forKey: prevActiveCacheKey) as? Deactivatable {
                    eventTransformer.deactivate()
                }
                if let activeCacheKey = activeCacheKey,
                   let eventTransformer = eventTransformerCache.value(forKey: activeCacheKey) as? Deactivatable {
                    eventTransformer.reactivate()
                }
            }
        }

        activeCacheKey = nil

        if sourcePid != nil, bypassEventsFromOtherApplications {
            os_log("Return noop transformer because this event is sent by %{public}s",
                   log: Self.log,
                   type: .info,
                   sourcePid?.bundleIdentifier ?? "(unknown)")
            return []
        }
        if let sourceBundleIdentifier = sourcePid?.bundleIdentifier,
           sourceBundleIdentifierBypassSet.contains(sourceBundleIdentifier) {
            os_log("Return noop transformer because the source application %{public}s is in the bypass set",
                   log: Self.log,
                   type: .info,
                   sourceBundleIdentifier)
            return []
        }

        let device = DeviceManager.shared.deviceFromCGEvent(cgEvent)
        let cacheKey = CacheKey(deviceMatcher: device.map { DeviceMatcher(of: $0) },
                                pid: pid,
                                screen: display)
        activeCacheKey = cacheKey
        if let eventTransformer = eventTransformerCache.value(forKey: cacheKey) {
            return eventTransformer
        }

        let scheme = ConfigurationState.shared.configuration.matchScheme(withDevice: device,
                                                                         withPid: pid,
                                                                         withDisplay: display)

        // TODO: Patch EventTransformer instead of rebuilding it

        os_log(
            "Initialize EventTransformer with scheme: %{public}@ (device=%{public}@, pid=%{public}@, screen=%{public}@)",
            log: Self.log,
            type: .info,
            String(describing: scheme),
            String(describing: device),
            String(describing: pid),
            String(describing: display)
        )

        var eventTransformer: [EventTransformer] = []

        if scheme.pointer.custom.enabled == true,
           scheme.pointer.disableAcceleration == true {
            eventTransformer.append(CustomPointerAccelerationTransformer(
                accel: scheme.pointer.custom.accel,
                limit: scheme.pointer.custom.limit,
                decay: scheme.pointer.custom.decay,
                sensitivity: scheme.pointer.custom.sensitivity
            ))
        }

        if let reverse = scheme.scrolling.$reverse {
            let vertical = reverse.vertical ?? false
            let horizontal = reverse.horizontal ?? false

            if vertical || horizontal {
                eventTransformer.append(ReverseScrollingTransformer(vertically: vertical, horizontally: horizontal))
            }
        }

        if let distance = scheme.scrolling.distance.horizontal {
            eventTransformer.append(LinearScrollingHorizontalTransformer(distance: distance))
        }

        if let distance = scheme.scrolling.distance.vertical {
            eventTransformer.append(LinearScrollingVerticalTransformer(distance: distance))
        }

        if scheme.scrolling.acceleration.vertical ?? 1 != 1 || scheme.scrolling.acceleration.horizontal ?? 1 != 1 ||
            scheme.scrolling.speed.vertical ?? 0 != 0 || scheme.scrolling.speed.horizontal ?? 0 != 0 {
            eventTransformer
                .append(ScrollingAccelerationSpeedAdjustmentTransformer(acceleration: scheme.scrolling.acceleration,
                                                                        speed: scheme.scrolling.speed))
        }

        if let timeout = scheme.buttons.clickDebouncing.timeout, timeout > 0,
           let buttons = scheme.buttons.clickDebouncing.buttons {
            let resetTimerOnMouseUp = scheme.buttons.clickDebouncing.resetTimerOnMouseUp ?? false
            for button in buttons {
                eventTransformer.append(ClickDebouncingTransformer(for: button,
                                                                   timeout: TimeInterval(timeout) / 1000,
                                                                   resetTimerOnMouseUp: resetTimerOnMouseUp))
            }
        }

        if let modifiers = scheme.scrolling.$modifiers {
            eventTransformer.append(ModifierActionsTransformer(modifiers: modifiers))
        }

        if scheme.buttons.switchPrimaryButtonAndSecondaryButtons == true {
            eventTransformer.append(SwitchPrimaryAndSecondaryButtonsTransformer())
        }

        if let mappings = scheme.buttons.mappings {
            eventTransformer.append(ButtonActionsTransformer(mappings: mappings))
        }

        if let universalBackForward = scheme.buttons.universalBackForward,
           universalBackForward != .none {
            eventTransformer.append(UniversalBackForwardTransformer(universalBackForward: universalBackForward))
        }

        eventTransformerCache.setValue(eventTransformer, forKey: cacheKey)

        return eventTransformer
    }
}

class CustomPointerAccelerationTransformer: EventTransformer {
    private static var lastTimestamps = NSMapTable<Device, NSNumber>(keyOptions: .weakMemory, valueOptions: .strongMemory)

    private let accel: Double
    private let limit: Double
    private let decay: Double
    private let sensitivity: Double

    init(accel: Decimal?, limit: Decimal?, decay: Decimal?, sensitivity: Decimal?) {
        self.accel = accel?.asTruncatedDouble ?? 0.04
        self.limit = limit?.asTruncatedDouble ?? 2.0
        self.decay = decay?.asTruncatedDouble ?? 2.0
        self.sensitivity = sensitivity?.asTruncatedDouble ?? 1.0
    }

    func transform(_ event: CGEvent) -> CGEvent? {
        guard [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged].contains(event.type) else {
            return event
        }

        let dx = Double(event.getIntegerValueField(.mouseEventDeltaX))
        let dy = Double(event.getIntegerValueField(.mouseEventDeltaY))

        guard dx != 0 || dy != 0 else {
            return event
        }

        guard let device = DeviceManager.shared.deviceFromCGEvent(event) else {
            return event
        }

        let currentTimestamp = event.timestamp
        let lastTimestamp = Self.lastTimestamps.object(forKey: device)?.uint64Value ?? 0
        Self.lastTimestamps.setObject(NSNumber(value: currentTimestamp), forKey: device)

        let distance = sqrt(pow(dx, 2) + pow(dy, 2))

        var speed = 0.0
        if lastTimestamp > 0 {
            let timeDiff = Double(currentTimestamp - lastTimestamp) / 1_000_000.0 // nanoseconds to milliseconds
            if timeDiff > 0 {
                // The speed unit in RawAccel is counts/ms.
                // The deltas from CGEvent are in points, not counts.
                // The parameters of the formula may need to be adjusted to get the desired effect.
                speed = distance / timeDiff
            }
        }

        let multiplier = calculateMultiplier(speed: speed)

        let newDx = dx * multiplier
        let newDy = dy * multiplier

        event.setIntegerValueField(.mouseEventDeltaX, value: Int64(round(newDx)))
        event.setIntegerValueField(.mouseEventDeltaY, value: Int64(round(newDy)))

        return event
    }

    private func calculateMultiplier(speed: Double) -> Double {
        if accel == 0 {
            return sensitivity
        }

        if decay == 0 {
            return sensitivity * (1 + accel * speed)
        }

        let arg = speed * abs(accel)
        var ans = (limit - 1) * (1 - 1 / (1 + arg / decay)) + 1

        if accel < 0 {
            ans = 1 / ans
        }

        return sensitivity * ans
    }
}
