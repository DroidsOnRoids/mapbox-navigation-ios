import CoreLocation
import MapboxDirections

/**
 The simulation mode type. Used for setting the simulation mode of the navigation service.
 */
public enum SimulationMode: Int {
    /**
     A setting of `.onPoorGPS` will enable simulation when we do not recieve a location update after the `poorGPSPatience` threshold has elapsed.
     */
    case onPoorGPS

    /**
     A setting of `.always` will simulate route progress at all times.
     */
    case always

    /**
     A setting of `.never` will never enable the location simulator, regardless of circumstances.
     */
    case never
}

/**
 A navigation service coordinates various nonvisual components that track the user as they navigate along a predetermined route. You use `MapboxNavigationService`, which conforms to this protocol, by itself as part of a custom user interface. A navigation service calls methods on its `delegate`, which conforms to the `NavigationServiceDelegate` protocol, whenever significant events or decision points occur along the route.

 A navigation service controls a `NavigationLocationManager` for determining the user’s location, and `Router` that tracks the user’s progress along the route.

 If you use a navigation service by itself, call `start()` when the user is ready to begin navigating along the route.
 */
public protocol NavigationService {
    /**
     The router object that tracks the user’s progress as they travel along a predetermined route.
     */
    var router: Router! { get }

    /**
     Details about the user’s progress along the current route, leg, and step.
     */
    var routeProgress: RouteProgress { get }

    /**
     The navigation service’s delegate, which is informed of significant events and decision points along the route.

     To synchronize your application’s state with the turn-by-turn navigation experience, set this property before starting the navigation session.
     */
    var delegate: NavigationServiceDelegate? { get set }

    /**
     Starts the navigation service.
     */
    func start()

    /**
     Stops the navigation service. You may call `start()` after calling `stop()`.
     */
    func stop()
}

/**
 A concrete implementation of the `NavigationService` protocol.

 If you use a navigation service by itself, call `start()` when the user is ready to begin navigating along the route.
 */
public class MapboxNavigationService: NSObject, NavigationService {
    /**
     The active router. By default, a `RouteController`.
     */
    public var router: Router! {
        return routeController
    }

    /**
     Use `routeProgress` from the active router.
     */
    public var routeProgress: RouteProgress {
        return routeController.routeProgress
    }

    /**
     The `NavigationService` delegate. Wraps `RouteControllerDelegate` messages.
     */
    public weak var delegate: NavigationServiceDelegate?

    /**
     The native location source. This is a `NavigationLocationManager` by default, but can be overridden with a custom location manager at initalization.
     */
    private var nativeLocationSource: NavigationLocationManager

    /**
     The simulation mode of the service.
     */
    public var simulationMode: SimulationMode

    private let routeController: RouteController

    /**
     Intializes a new `NavigationService`.

     - parameter route: The route to follow.
     - parameter routeIndex: The index of the route within the original `RouteResponse` object.
     - parameter directions: The Directions object that created `route`.
     - parameter locationSource: An optional override for the default `NaviationLocationManager`.
     - parameter simulationMode: The simulation mode desired.
     */
    public init(
        route: Route,
        routeIndex: Int,
        routeOptions: RouteOptions,
        directions: Directions? = nil,
        locationSource: NavigationLocationManager? = nil,
        simulating simulationMode: SimulationMode = .onPoorGPS
    ) {
        self.nativeLocationSource = locationSource ?? NavigationLocationManager()
        self.simulationMode = simulationMode
        self.routeController = RouteController(
            along: route,
            directions: directions ?? Directions.shared,
            locationManager: nativeLocationSource
        )

        super.init()

        routeController.delegate = self
    }

    deinit {
        stop()
    }

    public func start() {
        routeController.resume()
    }

    public func stop() {
        routeController.suspendLocationUpdates()
    }
}

extension MapboxNavigationService: RouteControllerDelegate {
    public func routeController(_ routeController: RouteController, willRerouteFrom location: CLLocation) {
        delegate?.navigationService(self, willRerouteFrom: location)
    }

    public func routeController(_ routeController: RouteController, didRerouteAlong route: Route) {
        delegate?.navigationService(self, didRerouteAlong: route, at: nativeLocationSource.location, proactive: false)
    }

    public func routeController(_ routeController: RouteController, didFailToRerouteWith error: Error) {
        delegate?.navigationService(self, didFailToRerouteWith: error)
    }

    public func routeController(_ routeController: RouteController, didUpdate progress: RouteProgress, with location: CLLocation, rawLocation: CLLocation) {
        delegate?.navigationService(self, didUpdate: progress, with: location, rawLocation: rawLocation)
    }

    public func routeController(_ routeController: RouteController, didArriveAt waypoint: Waypoint) -> Bool {
        delegate?.navigationService(self, didArriveAt: waypoint) ?? true
    }
}
