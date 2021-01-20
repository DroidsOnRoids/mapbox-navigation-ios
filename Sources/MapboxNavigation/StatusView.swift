import UIKit

/// :nodoc:
public protocol DeprecatedStatusViewDelegate: class {}

/**
 A protocol for listening in on changes made to a `StatusView`.
 */
@available(*, deprecated, message: "Add a target to StatusView for UIControl.Event.valueChanged instead.")
public protocol StatusViewDelegate: DeprecatedStatusViewDelegate {
    /**
     Indicates a value in the status view has changed by the user interacting with it.
     */
    @available(*, deprecated, message: "Add a target to StatusView for UIControl.Event.valueChanged instead.")
    func statusView(_ statusView: StatusView, valueChangedTo value: Double)
}

/// :nodoc:
private protocol StatusViewDelegateDeprecations {
    func statusView(_ statusView: StatusView, valueChangedTo value: Double)
}

/**
 :nodoc:
 
 A translucent bar that responds to tap and swipe gestures, similar to a scrubber or stepper control, and expands and collapses to maximize screen real estate.
 */
@IBDesignable
public class StatusView: UIControl {
    weak var activityIndicatorView: UIActivityIndicatorView!
    weak var textLabel: UILabel!
    public weak var delegate: DeprecatedStatusViewDelegate?
    var panStartPoint: CGPoint?
    
    var isCurrentlyVisible: Bool = false
    
    @available(swift, obsoleted: 0.1, renamed: "isEnabled")
    public var canChangeValue: Bool {
        fatalError()
    }
    
    var value: Double = 0 {
        didSet {
            sendActions(for: .valueChanged)
            (delegate as? StatusViewDelegateDeprecations)?.statusView(self, valueChangedTo: value)
        }
    }
    
    var statuses: [Status] = []

    public struct Status: Identifiable {
        public var id: String
//        let title: String
        var spinner: Bool = false
        let duration: TimeInterval
        var animated: Bool = true
        var interactive: Bool = false
        var priority: Priority
    }
    
    public struct Priority: RawRepresentable {
        public typealias RawValue = Int

        public var rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
//        — Highest Priority —
//            rerouting (rawValue = 0)
//            enable precise location (rawValue = 1)
//            simulation banner (rawValue = 2)
//        — Lowest Priority —
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    func commonInit() {
        let activityIndicatorView = UIActivityIndicatorView(style: .white)
        activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(activityIndicatorView)
        self.activityIndicatorView = activityIndicatorView
        
        let textLabel = UILabel()
        textLabel.contentMode = .bottom
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        textLabel.textColor = .white
        addSubview(textLabel)
        self.textLabel = textLabel
        
        let heightConstraint = heightAnchor.constraint(equalToConstant: 30)
        heightConstraint.priority = UILayoutPriority(rawValue: 999)
        heightConstraint.isActive = true
        textLabel.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        textLabel.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        
        activityIndicatorView.rightAnchor.constraint(equalTo: safeRightAnchor, constant: -10).isActive = true
        activityIndicatorView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        
        let recognizer = UIPanGestureRecognizer(target: self, action: #selector(StatusView.pan(_:)))
        addGestureRecognizer(recognizer)
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(StatusView.tap(_:)))
        addGestureRecognizer(tapRecognizer)
        
    }
    
    @objc func pan(_ sender: UIPanGestureRecognizer) {
        guard isEnabled else { return }
        
        let location = sender.location(in: self)
        
        if sender.state == .began {
            panStartPoint = location
        } else if sender.state == .changed {
            guard let startPoint = panStartPoint else { return }
            let offsetX = location.x - startPoint.x
            let coefficient = (offsetX / bounds.width) / 20.0
            value = Double(min(max(CGFloat(value) + coefficient, 0), 1))
        }
    }
    
    @objc func tap(_ sender: UITapGestureRecognizer) {
        guard isEnabled else { return }
        
        let location = sender.location(in: self)
        
        if sender.state == .ended {
            let incrementer: Double
            if UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft {
                incrementer = location.x < bounds.midX ? 0.1 : -0.1
            } else {
                incrementer = location.x > bounds.midX ? 0.1 : -0.1
            }
            value = min(max(value + incrementer, 0), 1)
        }
    }
    
    @available(*, deprecated, message: "Add a status using addNewStatus instead")
    public func showStatus(title: String, spinner spin: Bool = false, duration: TimeInterval, animated: Bool = true, interactive: Bool = false) {
        // show(title, showSpinner: spin, interactive: interactive)
        guard duration < .infinity else { return }
        hide(delay: duration, animated: animated)
    }
    
    /**
     Adds a new status to statuses array.
     */
    func addNewStatus(status: Status) {
        guard let firstWord = status.id.components(separatedBy: " ").first else { return }
        if let row = statuses.firstIndex(where: {$0.id.contains(firstWord)}) {
            statuses[row] = status
        } else {
            statuses.append(status)
        }
        manageStatuses()
    }
    
    /**
     Manages showing and hiding Statuses and the status view itself.
     */
    func manageStatuses(status: Status? = nil) {
        if statuses.isEmpty {
            hide(delay: status?.duration ?? 0, animated: status?.animated ?? true)
        } else {
            // if we hide a Status and there are Statuses left in the statuses array, show the Status with highest priority
            guard let highestPriorityStatus = statuses.min(by: {$0.priority.rawValue < $1.priority.rawValue}) else { return }
            show(status: highestPriorityStatus)
            hide(with: highestPriorityStatus, delay: highestPriorityStatus.duration)
        }
    }
    
    /**
     Hides a given Status without hiding the status view.
     */
    func hideStatus(using status: Status?) {
        guard let firstWord = status?.id.components(separatedBy: " ").first else { return }
        guard let row = statuses.firstIndex(where: {$0.id.contains(firstWord)}) else { return }
        let removedStatus = statuses.remove(at: row)
        manageStatuses(status: removedStatus)
    }
    
    func showSimulationStatus(speed: Int) {
        let format = NSLocalizedString("USER_IN_SIMULATION_MODE", bundle: .mapboxNavigation, value: "Simulating Navigation at %@×", comment: "The text of a banner that appears during turn-by-turn navigation when route simulation is enabled.")
        let title = String.localizedStringWithFormat(format, NumberFormatter.localizedString(from: speed as NSNumber, number: .decimal))
        let simulationStatus = Status(id: title, duration: .infinity, interactive: true, priority: StatusView.Priority(rawValue: 2))
        addNewStatus(status: simulationStatus)
    }
    
    /**
     Shows the status view with an optional spinner.
     */
    public func show(status: Status) {
        isEnabled = status.interactive
        textLabel.text = status.id
        activityIndicatorView.hidesWhenStopped = true
        if (!status.spinner) { activityIndicatorView.stopAnimating() }

        guard !isCurrentlyVisible, isHidden else { return }
                
        let show = {
            self.isHidden = false
            self.textLabel.alpha = 1
            if (status.spinner) { self.activityIndicatorView.isHidden = false }
            self.superview?.layoutIfNeeded()
        }
        
        UIView.defaultAnimation(0.3, animations:show, completion:{ _ in
            self.isCurrentlyVisible = true
            guard status.spinner else { return }
            self.activityIndicatorView.startAnimating()
        })
    }
    
    /**
     Hides the status view.
     */
    public func hide(with status: Status? = nil, delay: TimeInterval = 0, animated: Bool = true) {
        let hide = {
            if status == nil {
                self.isHidden = true
                self.textLabel.alpha = 0
                self.activityIndicatorView.isHidden = true
            } else {
                self.hideStatus(using: status)
            }
        }
        
        let animate = {
            let fireTime = DispatchTime.now() + delay
            DispatchQueue.main.asyncAfter(deadline: fireTime, execute: {
                if status == nil {
                    guard !self.isHidden, self.isCurrentlyVisible else { return }
                    
                    self.activityIndicatorView.stopAnimating()
                    UIView.defaultAnimation(0.3, delay: 0, animations: hide, completion: { _ in
                        self.isCurrentlyVisible = false
                    })
                } else {
                    self.hideStatus(using: status)
                }
            })
        }
        
        if animated {
            animate()
        } else {
            hide()
        }
    }
}
