import Foundation
import MapboxMaps

public class NavigationCamera: NSObject, ViewportDataSourceDelegate {
    
    public private(set) var navigationCameraState: NavigationCameraState = .idle {
        didSet {
            delegate?.navigationCameraStateDidChange(navigationCameraState)
            NotificationCenter.default.post(name: .navigationCameraStateDidChange, object: self, userInfo: [
                NavigationCamera.navigationCameraStateDidChangeKey: navigationCameraState,
            ])
        }
    }
    
    public var viewportDataSource: ViewportDataSource {
        didSet {
            viewportDataSource.delegate = self
        }
    }
    
    public var cameraStateTransition: CameraStateTransition
    
    weak var mapView: MapView?
    
    weak var delegate: NavigationCameraDelegate?
    
    var navigationCameraType: NavigationCameraType = .mobile
    
    public required init(_ mapView: MapView, navigationCameraType: NavigationCameraType = .mobile) {
        self.mapView = mapView
        self.viewportDataSource = NavigationViewportDataSource(mapView)
        self.cameraStateTransition = NavigationCameraStateTransition(mapView)
        self.navigationCameraType = navigationCameraType
        
        super.init()
        
        self.viewportDataSource.delegate = self
        
        setupGestureRegonizers()
    }
    
    // MARK: - Setting-up methods
    
    func setupGestureRegonizers() {
        makeGestureRecognizersRespectCourseTracking()
    }
    
    // MARK: - ViewportDataSourceDelegate methods
    
    public func viewportDataSource(_ dataSource: ViewportDataSource, didUpdate cameraOptions: [String : CameraOptions]) {
        NSLog("[NavigationCamera] Current camera state: \(navigationCameraState)")
        
        switch navigationCameraState {
        case .following:
            switch navigationCameraType {
            case .headUnit:
                if let followingHeadUnitCamera = cameraOptions[NavigationViewportDataSource.followingHeadUnitCameraKey] {
                    cameraStateTransition.updateForFollowing(followingHeadUnitCamera, completion: nil)
                }
            case .mobile:
                if let followingMobileCamera = cameraOptions[NavigationViewportDataSource.followingMobileCameraKey] {
                    cameraStateTransition.updateForFollowing(followingMobileCamera, completion: nil)
                }
            }
            break

        case .overview:
            switch navigationCameraType {
            case .headUnit:
                if let overviewHeadUnitCamera = cameraOptions[NavigationViewportDataSource.overviewHeadUnitCameraKey] {
                    cameraStateTransition.updateForOverview(overviewHeadUnitCamera, completion: nil)
                }
            case .mobile:
                if let overviewMobileCamera = cameraOptions[NavigationViewportDataSource.overviewMobileCameraKey] {
                    cameraStateTransition.updateForOverview(overviewMobileCamera, completion: nil)
                }
            }
            break

        case .idle, .transitionToFollowing, .transitionToOverview:
            break
        }
    }
    
    // MARK: - NavigationCamera state related methods
    
    public func requestNavigationCameraToFollowing() {
        switch navigationCameraState {
        case .transitionToFollowing, .following:
            return
            
        case .idle, .transitionToOverview, .overview:
            navigationCameraState = .transitionToFollowing
            
            var cameraOptions: CameraOptions
            switch navigationCameraType {
            case .mobile:
                cameraOptions = viewportDataSource.followingMobileCamera
            case .headUnit:
                cameraOptions = viewportDataSource.followingHeadUnitCamera
            }
            
            cameraStateTransition.transitionToFollowing(cameraOptions) { _ in
                self.navigationCameraState = .following
            }
            
            break
        }
    }
    
    public func requestNavigationCameraToOverview() {
        switch navigationCameraState {
        case .transitionToOverview, .overview:
            return
            
        case .idle, .transitionToFollowing, .following:
            navigationCameraState = .transitionToOverview
            
            var cameraOptions: CameraOptions
            switch navigationCameraType {
            case .mobile:
                cameraOptions = viewportDataSource.overviewMobileCamera
            case .headUnit:
                cameraOptions = viewportDataSource.overviewHeadUnitCamera
            }
            
            cameraStateTransition.transitionToOverview(cameraOptions) { _ in
                self.navigationCameraState = .overview
            }
            
            break
        }
    }
    
    @objc public func requestNavigationCameraToIdle() {
        NSLog("[NavigationCamera] Requesting NavigationCamera to move to idle state.")
        if navigationCameraState == .idle { return }
        
        // TODO: Cancel all pending animations.
        
        navigationCameraState = .idle
    }
    
    /**
     Modifies `MapView` gesture recognizers to disable follow mode and move `NavigationCamera` to
     `NavigationCameraState.idle` state.
     */
    func makeGestureRecognizersRespectCourseTracking() {
        for gestureRecognizer in mapView?.gestureRecognizers ?? []
        where gestureRecognizer is UIPanGestureRecognizer || gestureRecognizer is UIRotationGestureRecognizer {
            gestureRecognizer.addTarget(self, action: #selector(requestNavigationCameraToIdle))
            break
        }
    }
}
