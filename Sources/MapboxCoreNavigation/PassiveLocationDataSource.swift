import MapboxNavigationNative
import CoreLocation
import MapboxDirections
import MapboxAccounts

/**
 An object that notifies its delegate when the user’s location changes, minimizing the noise that normally accompanies location updates from a `CLLocationManager` object.
 
 Unlike `Router` classes such as `RouteController` and `LegacyRouteController`, this class operates without a predefined route, matching the user’s location to the road network at large. You can use a passive location manager to determine a starting point for a route that you calculate using the `Directions.calculate(_:completionHandler:)` method. If the user happens to be moving while you calculate the route, the passive location manager makes it less likely that the route will begin with a short segment on a side road or driveway and a confusing instruction to turn onto the current road.
 
 To find out when the user’s location changes, implement the `PassiveLocationDataSourceDelegate` protocol, or observe `Notification.Name.passiveLocationDataSourceDidUpdate` notifications for more detailed information.
 */
open class PassiveLocationDataSource: NSObject {
    /**
     Initializes the location data source with the given directions service.
     
     - parameter directions: The directions service that allows the location data source to access road network data. If this argument is omitted, the shared `Directions` object is used.
     - parameter systemLocationManager: The location manager that provides raw locations for the receiver to match against the road network.
     
     - postcondition: Call `startUpdatingLocation(completionHandler:)` afterwards to begin receiving location updates.
     */
    public required init(directions: Directions = Directions.shared, systemLocationManager: NavigationLocationManager? = nil) {
        self.directions = directions

        self.systemLocationManager = systemLocationManager ?? NavigationLocationManager()
        self.navigatorWithHistory = NavigatorProvider.sharedWeakNavigator()
        
        super.init()
        
        self.systemLocationManager.delegate = self
    }
    
    /**
     The directions service that allows the location data source to access road network data.
     */
    public let directions: Directions
    
    /**
     The location manager that provides raw locations for the receiver to match against the road network.
     */
    public let systemLocationManager: NavigationLocationManager
    
    /**
     The underlying navigator that performs map matching.
     */
    var navigator: Navigator {
        navigatorWithHistory.navigator
    }
    private var navigatorWithHistory: NavigatorWithHistory
    
    /**
     The location data source’s delegate.
     */
    public weak var delegate: PassiveLocationDataSourceDelegate?
    
    /**
     Starts the generation of location updates with an optional completion handler that gets called when the location data source is ready to receive snapped location updates.
     */
    public func startUpdatingLocation() {
        systemLocationManager.startUpdatingLocation()
    }
    
    /**
     Manually sets the current location.
     
     This method stops any automatic location updates.
     */
    public func updateLocation(_ location: CLLocation?) {
        guard let location = location else { return }
        systemLocationManager.stopUpdatingLocation()
        systemLocationManager.stopUpdatingHeading()
        self.didUpdate(locations: [location])
    }

    private func didUpdate(locations: [CLLocation]) {
        for location in locations {
            _ = try? navigator.updateLocation(for: FixLocation(location))
        }

        guard let lastRawLocation = locations.last else {
            return
        }

        let status = navigator.status(at: lastRawLocation.timestamp)
        let lastLocation = CLLocation(status.location)

        delegate?.passiveLocationDataSource(self, didUpdateLocation: lastLocation, rawLocation: lastRawLocation)
        let matches = status.map_matcher_output.matches.map {
            Match(legs: [], shape: nil, distance: -1, expectedTravelTime: -1, confidence: $0.proba, weight: .routability(value: 1))
        }
        NotificationCenter.default.post(name: .passiveLocationDataSourceDidUpdate, object: self, userInfo: [
            NotificationUserInfoKey.locationKey: lastLocation,
            NotificationUserInfoKey.rawLocationKey: lastRawLocation,
            NotificationUserInfoKey.matchesKey: matches,
            NotificationUserInfoKey.roadNameKey: status.roadName,
        ])
    }
}

extension PassiveLocationDataSource: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        didUpdate(locations: locations)
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        delegate?.passiveLocationDataSource(self, didUpdateHeading: newHeading)
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        delegate?.passiveLocationDataSource(self, didFailWithError: error)
    }
    
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if #available(iOS 14.0, *) {
            delegate?.passiveLocationDataSourceDidChangeAuthorization(self)
        }
    }
}

/**
 A delegate of a `PassiveLocationDataSource` object implements methods that the location data source calls as the user’s location changes.
 */
public protocol PassiveLocationDataSourceDelegate: class {
    /// - seealso: `CLLocationManagerDelegate.locationManagerDidChangeAuthorization(_:)`
    @available(iOS 14.0, *)
    func passiveLocationDataSourceDidChangeAuthorization(_ dataSource: PassiveLocationDataSource)
    
    /// - seealso: `CLLocationManagerDelegate.locationManager(_:didUpdateLocations:)`
    func passiveLocationDataSource(_ dataSource: PassiveLocationDataSource, didUpdateLocation location: CLLocation, rawLocation: CLLocation)
    
    /// - seealso: `CLLocationManagerDelegate.locationManager(_:didUpdateHeading:)`
    func passiveLocationDataSource(_ dataSource: PassiveLocationDataSource, didUpdateHeading newHeading: CLHeading)
    
    /// - seealso: `CLLocationManagerDelegate.locationManager(_:didFailWithError:)`
    func passiveLocationDataSource(_ dataSource: PassiveLocationDataSource, didFailWithError error: Error)
}

extension TileEndpointConfiguration {
    /**
     Initializes an object that configures a navigator to obtain routing tiles of the given version from an endpoint, using the given credentials.
              
           - parameter credentials: Credentials for accessing road network data.
           - parameter tilesVersion: Routing tile version.
           - parameter minimumDaysToPersistVersion: The minimum age in days that a tile version much reach before a new version can be requested from the tile endpoint.
     */
    convenience init(credentials: DirectionsCredentials, tilesVersion: String, minimumDaysToPersistVersion: Int?) {
        let host = credentials.host.absoluteString
        guard let accessToken = credentials.accessToken, !accessToken.isEmpty else {
            preconditionFailure("No access token specified in Info.plist")
        }
        let skuTokenProvider = SkuTokenProvider(with: credentials)
        
        
        self.init(host: host,
                  dataset: "mapbox/driving",
                  version: tilesVersion,
                  token: accessToken,
                  userAgent: URLSession.userAgent,
                  navigatorVersion: "",
                  skuTokenSource: skuTokenProvider,
                  minDiffInDaysToConsiderServerVersion: minimumDaysToPersistVersion as NSNumber?)
    }
}
