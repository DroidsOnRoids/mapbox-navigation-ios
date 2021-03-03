import CoreLocation
import MapboxDirections

/**
 A navigation service delegate interacts with one or more `NavigationService` instances (such as `MapboxNavigationService` objects) during turn-by-turn navigation. This protocol is the main way that your application can synchronize its state with the SDK’s location-related functionality. Each of the protocol’s methods is optional.

 As the user progresses along a route, a navigation service informs its delegate about significant events as they occur, and the delegate has opportunities to influence the route and its presentation. For example, when the navigation service reports that the user has arrived at the destination, your delegate implementation could present information about the destination. It could also customize individual visual or spoken instructions along the route by returning modified instruction objects.

 Assign a `NavigationServiceDelegate` instance to the `NavigationService.delegate` property of the navigation service before you start the service.

 The `RouteControllerDelegate` protocol defines corresponding methods so that a `RouteController` instance can interact with an object that is both a route controller delegate and a navigation service, which in turn interacts with a navigation service delegate. Additionally, several location-related methods in this protocol have corresponding methods in the `NavigationViewControllerDelegate` protocol, which can be convenient if you are using the navigation service in conjunction with a `NavigationViewController`. Normally, you would either implement methods in `NavigationServiceDelegate` or `NavigationViewControllerDelegate` but not `RouteControllerDelegate`.

 - seealso: NavigationViewControllerDelegate
 - seealso: RouteControllerDelegate
 */
public protocol NavigationServiceDelegate: class {
    /**
     Called immediately before the navigation service calculates a new route.

     This method is called after `navigationService(_:shouldRerouteFrom:)` is called, simultaneously with the `Notification.Name.routeControllerWillReroute` notification being posted, and before `navigationService(_:didRerouteAlong:)` is called.

     - parameter service: The navigation service that will calculate a new route.
     - parameter location: The user’s current location.
     */
    func navigationService(_ service: NavigationService, willRerouteFrom location: CLLocation)

    /**
     Called immediately after the navigation service receives a new route.

     This method is called after `navigationService(_:willRerouteFrom:)` and simultaneously with the `Notification.Name.routeControllerDidReroute` notification being posted.

     - parameter service: The navigation service that has calculated a new route.
     - parameter route: The new route.
     */
    func navigationService(_ service: NavigationService, didRerouteAlong route: Route, at location: CLLocation?, proactive: Bool)

    /**
     Called when the navigation service fails to receive a new route.

     This method is called after `navigationService(_:willRerouteFrom:)` and simultaneously with the `Notification.Name.routeControllerDidFailToReroute` notification being posted.

     - parameter service: The navigation service that has calculated a new route.
     - parameter error: An error raised during the process of obtaining a new route.
     */
    func navigationService(_ service: NavigationService, didFailToRerouteWith error: Error)

    /**
     Called when the navigation service updates the route progress model.

     - parameter service: The navigation service that received the new locations.
     - parameter progress: the RouteProgress model that was updated.
     - parameter location: the guaranteed location, possibly snapped, associated with the progress update.
     - parameter rawLocation: the raw location, from the location manager, associated with the progress update.
     */
    func navigationService(_ service: NavigationService, didUpdate progress: RouteProgress, with location: CLLocation, rawLocation: CLLocation)

    /**
     Called when the navigation service arrives at a waypoint.

     You can implement this method to prevent the navigation service from automatically advancing to the next leg. For example, you can and show an interstitial sheet upon arrival and pause navigation by returning `false`, then continue the route when the user dismisses the sheet. If this method is unimplemented, the navigation service automatically advances to the next leg when arriving at a waypoint.

     - postcondition: If you return false, you must manually advance to the next leg: obtain the value of the `routeProgress` property, then increment the `RouteProgress.legIndex` property.
     - parameter service: The navigation service that has arrived at a waypoint.
     - parameter waypoint: The waypoint that the controller has arrived at.
     - returns: True to advance to the next leg, if any, or false to remain on the completed leg.
     */
    func navigationService(_ service: NavigationService, didArriveAt waypoint: Waypoint) -> Bool
}

public extension NavigationServiceDelegate {
    func navigationService(_ service: NavigationService, willRerouteFrom location: CLLocation) {}

    func navigationService(_ service: NavigationService, didRerouteAlong route: Route, at location: CLLocation?, proactive: Bool) {}

    func navigationService(_ service: NavigationService, didFailToRerouteWith error: Error) {}

    func navigationService(_ service: NavigationService, didUpdate progress: RouteProgress, with location: CLLocation, rawLocation: CLLocation) {}

    func navigationService(_ service: NavigationService, didArriveAt waypoint: Waypoint) -> Bool {
        return true
    }
}
