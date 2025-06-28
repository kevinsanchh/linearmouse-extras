// MIT License
// Copyright (c) 2021-2024 LinearMouse

import Foundation

extension Scheme {
    struct Acceleration: Equatable, ClampRange {
        typealias Value = Decimal

        static var range: ClosedRange<Value> = 0 ... 20
    }

    struct Speed: Equatable, ClampRange {
        typealias Value = Decimal

        static var range: ClosedRange<Value> = 0 ... 1
    }

    struct Pointer: Codable, Equatable, ImplicitInitable {
        @ImplicitOptional var custom: CustomAcceleration
        
        @Clamp<Acceleration> var acceleration: Decimal?

        @Clamp<Speed> var speed: Decimal?

        var disableAcceleration: Bool?
        
        
    }
}

extension Scheme.Pointer {
    func merge(into pointer: inout Self) {
        if let acceleration = acceleration {
            pointer.acceleration = acceleration
        }
        
        if let speed = speed {
            pointer.speed = speed
        }
        
        if let disableAcceleration = disableAcceleration {
            pointer.disableAcceleration = disableAcceleration
        }
        $custom?.merge(into: &pointer.custom)
    }

    func merge(into pointer: inout Self?) {
        if pointer == nil {
            pointer = Self()
        }

        merge(into: &pointer!)
    }
}

extension Scheme.Pointer {
    struct CustomAcceleration: Codable, Equatable, ImplicitInitable {
        var enabled: Bool?
        @Clamp<NaturalAcceleration.Accel> var accel: Decimal?
        @Clamp<NaturalAcceleration.Limit> var limit: Decimal?
        @Clamp<NaturalAcceleration.Decay> var decay: Decimal?
        @Clamp<NaturalAcceleration.Sensitivity> var sensitivity: Decimal?
    }

    struct NaturalAcceleration {
        struct Accel: ClampRange, Equatable {
            static let range: ClosedRange<Decimal> = -1...1
        }

        struct Limit: ClampRange, Equatable {
            static let range: ClosedRange<Decimal> = 1...10
        }

        struct Decay: ClampRange, Equatable {
            static let range: ClosedRange<Decimal> = 0...10
        }

        struct Sensitivity: ClampRange, Equatable {
            static let range: ClosedRange<Decimal> = 0...10
        }
    }
}

extension Scheme.Pointer.CustomAcceleration {
    func merge(into custom: inout Self) {
        if let enabled = enabled {
            custom.enabled = enabled
        }
        if let accel = accel {
            custom.accel = accel
        }
        if let limit = limit {
            custom.limit = limit
        }
        if let decay = decay {
            custom.decay = decay
        }
        if let sensitivity = sensitivity {
            custom.sensitivity = sensitivity
        }
    }

    func merge(into custom: inout Self?) {
        if custom == nil {
            custom = Self()
        }
        merge(into: &custom!)
    }
}
