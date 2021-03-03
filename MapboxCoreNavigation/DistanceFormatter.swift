import CoreLocation

extension CLLocationDistance {
    
    static let metersPerMile: CLLocationDistance = 1_609.344
    static let feetPerMeter: CLLocationDistance = 3.28084
    
    // Returns the distance converted to miles
    var miles: Double {
        return self / .metersPerMile
    }
    
    // Returns the distance converted to feet
    var feet: Double {
        return self * .feetPerMeter
    }
    
    // Returns the distance converted to yards
    var yards: Double {
        return feet / 3
    }
    
    // Returns the distance converted to kilometers
    var kilometers: Double {
        return self / 1000
    }
    
    // Returns the distance in meters converted from miles
    func inMiles() -> Double {
        return self * .metersPerMile
    }
    
    // Returns the distance in meters converted from yards
    func inYards() -> Double {
        return self * .feetPerMeter / 3
    }
    
    func converted(to unit: LengthFormatter.Unit) -> Double {
        switch unit {
        case .millimeter:
            return self / 1_000
        case .centimeter:
            return self / 100
        case .meter:
            return self
        case .kilometer:
            return kilometers
        case .inch:
            return feet * 12
        case .foot:
            return feet
        case .yard:
            return yards
        case .mile:
            return miles
        }
    }
}

struct RoundingTable {
    struct Threshold {
        let maximumDistance: CLLocationDistance
        let roundingIncrement: Double
        let unit: LengthFormatter.Unit
        let maximumFractionDigits: Int
        
        @available(iOS 10.0, *)
        func measurement(for distance: CLLocationDistance) -> Measurement<UnitLength> {
            switch unit {
            case .millimeter:
                return Measurement(value: distance.kilometers / 1e6, unit: .millimeters)
            case .centimeter:
                return Measurement(value: distance.kilometers / 1e5, unit: .centimeters)
            case .meter:
                return Measurement(value: distance.kilometers / 1e3, unit: .meters)
            case .kilometer:
                return Measurement(value: distance.kilometers, unit: .kilometers)
            case .inch:
                return Measurement(value: distance.feet * 12, unit: .inches)
            case .foot:
                return Measurement(value: distance.feet, unit: .feet)
            case .yard:
                return Measurement(value: distance.yards, unit: .yards)
            case .mile:
                return Measurement(value: distance.miles, unit: .miles)
            }
        }
        
        func localizedDistanceString(for distance: CLLocationDistance, using formatter: DistanceFormatter) -> String {
            switch unit {
            case .mile:
                return formatter.string(fromValue: distance.miles, unit: unit)
            case .foot:
                return formatter.string(fromValue: distance.feet, unit: unit)
            case .yard:
                return formatter.string(fromValue: distance.yards, unit: unit)
            case .kilometer:
                return formatter.string(fromValue: distance.kilometers, unit: unit)
            default:
                return formatter.string(fromValue: distance, unit: unit)
            }
        }
    }
    
    let thresholds: [Threshold]
    
    func threshold(for distance: CLLocationDistance) -> Threshold {
        for threshold in thresholds {
            if distance < threshold.maximumDistance {
                return threshold
            }
        }
        return thresholds.last!
    }
}

extension NSAttributedStringKey {
    public static let quantity = NSAttributedStringKey(rawValue: "MBQuantity")
}

/// Provides appropriately formatted, localized descriptions of linear distances.
@objc(MBDistanceFormatter)
open class DistanceFormatter: LengthFormatter {
    
    let nonFractionalLengthFormatter = LengthFormatter()
    
    /// Indicates the most recently used unit
    public private(set) var unit: LengthFormatter.Unit = .millimeter

    // Rounding tables for metric, imperial, and UK measurement systems. The last threshold is used as a default.
    lazy var roundingTableMetric: RoundingTable = {
        return RoundingTable(thresholds: [.init(maximumDistance: 25, roundingIncrement: 5, unit: .meter, maximumFractionDigits: 0),
                                          .init(maximumDistance: 100, roundingIncrement: 25, unit: .meter, maximumFractionDigits: 0),
                                          .init(maximumDistance: 999, roundingIncrement: 50, unit: .meter, maximumFractionDigits: 0),
                                          .init(maximumDistance: 3_000, roundingIncrement: 0, unit: .kilometer, maximumFractionDigits: 1),
                                          .init(maximumDistance: 5_000, roundingIncrement: 0, unit: .kilometer, maximumFractionDigits: 0)])
    }()
    
    lazy var roundingTableUK: RoundingTable = {
        return RoundingTable(thresholds: [.init(maximumDistance: 20.inYards(), roundingIncrement: 10, unit: .yard, maximumFractionDigits: 0),
                                          .init(maximumDistance: 100.inYards(), roundingIncrement: 25, unit: .yard, maximumFractionDigits: 0),
                                          .init(maximumDistance: 0.1.inMiles(), roundingIncrement: 50, unit: .yard, maximumFractionDigits: 1),
                                          .init(maximumDistance: 3.inMiles(), roundingIncrement: 0.1, unit: .mile, maximumFractionDigits: 1),
                                          .init(maximumDistance: 5.inMiles(), roundingIncrement: 0, unit: .mile, maximumFractionDigits: 0)])
    }()
    
    lazy var roundingTableImperial: RoundingTable = {
        return RoundingTable(thresholds: [.init(maximumDistance: 0.1.inMiles(), roundingIncrement: 50, unit: .foot, maximumFractionDigits: 0),
                                          .init(maximumDistance: 3.inMiles(), roundingIncrement: 0.1, unit: .mile, maximumFractionDigits: 1),
                                          .init(maximumDistance: 5.inMiles(), roundingIncrement: 0, unit: .mile, maximumFractionDigits: 0)])
    }()
    
    /**
     Intializes a new `DistanceFormatter`.
     
     - parameter approximate: approximates the distances.
     */
    @objc public override init() {
        super.init()
        self.numberFormatter.locale = .nationalizedCurrent
    }
    
    public required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }
    
    func threshold(for distance: CLLocationDistance) -> RoundingTable.Threshold {
        if NavigationSettings.shared.usesMetric {
            return roundingTableMetric.threshold(for: distance)
        } else if numberFormatter.locale.identifier == "en-GB" {
            return roundingTableUK.threshold(for: distance)
        } else {
            return roundingTableImperial.threshold(for: distance)
        }
    }
    
    /**
     Returns a more human readable `String` from a given `CLLocationDistance`.
     
     The user’s `Locale` is used here to set the units.
    */
    @objc public func string(from distance: CLLocationDistance) -> String {
        numberFormatter.positivePrefix = ""
        numberFormatter.positiveSuffix = ""
        numberFormatter.decimalSeparator = nonFractionalLengthFormatter.numberFormatter.decimalSeparator
        numberFormatter.alwaysShowsDecimalSeparator = nonFractionalLengthFormatter.numberFormatter.alwaysShowsDecimalSeparator
        numberFormatter.usesSignificantDigits = false
        return formattedDistance(distance)
    }
    
    @objc open override func string(fromMeters numberInMeters: Double) -> String {
        return self.string(from: numberInMeters)
    }
    
    func formattedDistance(_ distance: CLLocationDistance) -> String {
        let threshold = self.threshold(for: distance)
        numberFormatter.maximumFractionDigits = threshold.maximumFractionDigits
        numberFormatter.roundingIncrement = threshold.roundingIncrement as NSNumber
        unit = threshold.unit
        return threshold.localizedDistanceString(for: distance, using: self)
    }
    
    @available(iOS 10.0, *)
    @objc(measurementOfDistance:)
    public func measurement(of distance: CLLocationDistance) -> Measurement<UnitLength> {
        let threshold = self.threshold(for: distance)
        numberFormatter.maximumFractionDigits = threshold.maximumFractionDigits
        numberFormatter.roundingIncrement = threshold.roundingIncrement as NSNumber
        unit = threshold.unit
        return threshold.measurement(for: distance)
    }
    
    /**
     Returns an attributed string containing the formatted, converted distance.
     
     `NSAttributedStringKey.quantity` is applied to the numeric quantity.
     */
    @objc open override func attributedString(for obj: Any, withDefaultAttributes attrs: [NSAttributedStringKey : Any]? = nil) -> NSAttributedString? {
        guard let distance = obj as? CLLocationDistance else {
            return nil
        }
        
        let string = self.string(from: distance)
        let attributedString = NSMutableAttributedString(string: string, attributes: attrs)
        let convertedDistance = distance.converted(to: threshold(for: distance).unit)
        if let quantityString = numberFormatter.string(from: convertedDistance as NSNumber) {
            // NSMutableAttributedString methods accept NSRange, not Range.
            let quantityRange = (string as NSString).range(of: quantityString)
            if quantityRange.location != NSNotFound {
                attributedString.addAttribute(.quantity, value: distance as NSNumber, range: quantityRange)
            }
        }
        return attributedString
    }
}
