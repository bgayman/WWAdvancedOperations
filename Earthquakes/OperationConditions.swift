//
//  OperationConditions.swift
//  Earthquakes
//
//  Created by App Partner on 6/22/17.
//  Copyright © 2017 App Partner. All rights reserved.
//

import Foundation
import SystemConfiguration
import CloudKit
import PassKit
import CoreLocation
import EventKit
import Photos
import HealthKit

// MARK: - Conditions
let OperationConditionKey = "OperationCondition"

protocol OperationCondition
{
    static var name: String { get }
    static var isMutuallyExclusive: Bool { get }
    
    func dependency(for operation: BaseOperation) -> Operation?
    func evaluate(for operation: BaseOperation, completion: @escaping (OperationConditionResult) -> ())
}

struct OperationConditionEvaluator
{
    static func evaluate(_ conditions: [OperationCondition], operation: BaseOperation, completion: @escaping ([NSError]) -> Void)
    {
        let conditionGroup = DispatchGroup()
        var results = [OperationConditionResult?](repeating: nil, count: conditions.count)
        for (index, condition) in conditions.enumerated()
        {
            conditionGroup.enter()
            condition.evaluate(for: operation)
            { result in
                results[index] = result
                conditionGroup.leave()
            }
        }
        
        conditionGroup.notify(queue: DispatchQueue.global())
        {
            var failures = results.flatMap { $0?.error }
            
            if operation.isCancelled
            {
                failures.append(NSError(code: .conditionFailed))
            }
            completion(failures)
        }
    }
}

struct SilentCondition<T: OperationCondition>: OperationCondition
{
    let condition: T
    
    static var name: String
    {
        return "Silent<\(T.name)>"
    }
    
    static var isMutuallyExclusive: Bool
    {
        return T.isMutuallyExclusive
    }
    
    init(condition: T)
    {
        self.condition = condition
    }
    
    func dependency(for operation: BaseOperation) -> Operation?
    {
        return nil
    }
    
    func evaluate(for operation: BaseOperation, completion: @escaping (OperationConditionResult) -> ())
    {
        condition.evaluate(for: operation, completion: completion)
    }
}

struct NegatedCondition<T: OperationCondition>: OperationCondition
{
    static var name: String
    {
        return "Not<\(T.name)>"
    }
    
    static var negatedConditionKey: String
    {
        return "NegatedCondition"
    }
    
    static var isMutuallyExclusive: Bool
    {
        return T.isMutuallyExclusive
    }
    
    let condition: T
    
    init(condition: T)
    {
        self.condition = condition
    }
    
    func dependency(for operation: BaseOperation) -> Operation?
    {
        return condition.dependency(for: operation)
    }
    
    func evaluate(for operation: BaseOperation, completion: @escaping (OperationConditionResult) -> ())
    {
        condition.evaluate(for: operation)
        { (result) in
            if result == .satisfied
            {
                let error = NSError(code: .conditionFailed, userInfo: [OperationConditionKey: type(of: self).name,
                                                                       type(of: self).negatedConditionKey: type(of: self.condition).name])
                completion(.failed(error))
            }
            else
            {
                completion(.satisfied)
            }
        }
    }
}

struct NoCancelledDependencies: OperationCondition
{
    static let name = "NoCalledDependencies"
    static let cancelledDependenciesKey = "CancelledDependencies"
    static let isMutuallyExclusive = false
    
    init(){}
    
    func dependency(for operation: BaseOperation) -> Operation?
    {
        return nil
    }
    
    func evaluate(for operation: BaseOperation, completion: @escaping (OperationConditionResult) -> ())
    {
        let cancelled = operation.dependencies.filter { $0.isCancelled }
        
        if cancelled.isEmpty
        {
            completion(.satisfied)
        }
        else
        {
            let error = NSError(code: .conditionFailed, userInfo: [OperationConditionKey: type(of: self).name,
                                                                   type(of: self).cancelledDependenciesKey: cancelled])
            completion(.failed(error))
        }
    }
}

struct MutuallyExclusive<T>: OperationCondition
{
    static var name: String
    {
        return "MutuallyExclusive<\(T.self)>"
    }
    
    static var isMutuallyExclusive: Bool
    {
        return true
    }
    
    init(){}
    
    func dependency(for operation: BaseOperation) -> Operation?
    {
        return nil
    }
    
    func evaluate(for operation: BaseOperation, completion: @escaping (OperationConditionResult) -> ())
    {
        completion(.satisfied)
    }
}

enum Alert {}

typealias AlertPresentation = MutuallyExclusive<Alert>

struct ReachabilityCondition: OperationCondition
{
    static let hostKey = "Host"
    static let name = "Reachability"
    static let isMutuallyExclusive = false
    
    let host: URL
    
    init(host: URL)
    {
        self.host = host
    }
    
    func dependency(for operation: BaseOperation) -> Operation?
    {
        return nil
    }
    
    func evaluate(for operation: BaseOperation, completion: @escaping (OperationConditionResult) -> ())
    {
        ReachabilityController.requestReachability(host)
        { (reachable) in
            if reachable
            {
                completion(.satisfied)
            }
            else
            {
                let error = NSError(code: .conditionFailed, userInfo: [OperationConditionKey: type(of: self).name,
                                                                       type(of: self).hostKey: self.host])
                completion(.failed(error))
            }
        }
    }
}

fileprivate class ReachabilityController
{
    static var reachabilityRefs = [String: SCNetworkReachability]()
    
    static let reachabilityQueue = DispatchQueue(label: "Operations.Reachability", qos: .default, attributes: [])
    
    static func requestReachability(_ url: URL, completionHandler: @escaping (Bool) -> ())
    {
        guard let host = url.host else { completionHandler(false); return }
        reachabilityQueue.async
            {
                var ref = self.reachabilityRefs[host]
                
                if ref == nil
                {
                    let hostString = host as NSString
                    ref = SCNetworkReachabilityCreateWithName(nil, hostString.utf8String!)
                }
                
                if let ref = ref
                {
                    self.reachabilityRefs[host] = ref
                    
                    var reachable = false
                    var flags: SCNetworkReachabilityFlags = []
                    if SCNetworkReachabilityGetFlags(ref, &flags)
                    {
                        reachable = flags.contains(.reachable)
                    }
                    completionHandler(reachable)
                }
                else
                {
                    completionHandler(false)
                }
        }
    }
}

struct CloudContainerCondition: OperationCondition
{
    static let name = "CloudContainer"
    static let containerKey = "CKContainer"
    
    static let isMutuallyExclusive = false
    
    let container: CKContainer
    let permission: CKApplicationPermissions
    
    init(container: CKContainer, permission: CKApplicationPermissions = [])
    {
        self.container = container
        self.permission = permission
    }
    
    func dependency(for operation: BaseOperation) -> Operation? {
        return CloudKitPermissionOperation(container: container, permission: permission)
    }
    
    func evaluate(for operation: BaseOperation, completion: @escaping (OperationConditionResult) -> ())
    {
        container.verify(permission, request: false)
        { (error) in
            if let error = error
            {
                let conditionError = NSError(code: .conditionFailed, userInfo: [OperationConditionKey: type(of: self).name,
                                                                                type(of: self).containerKey: self.container,
                                                                                NSUnderlyingErrorKey: error])
                completion(.failed(conditionError))
            }
            else
            {
                completion(.satisfied)
            }
        }
    }
}

fileprivate class CloudKitPermissionOperation: BaseOperation
{
    let container: CKContainer
    let permission: CKApplicationPermissions
    
    init(container: CKContainer, permission: CKApplicationPermissions)
    {
        self.container = container
        self.permission = permission
        super.init()
        
        if permission != []
        {
            add(AlertPresentation())
        }
    }
    
    override func execute()
    {
        container.verify(permission, request: true)
        { (error) in
            self.finishWithError(error)
        }
    }
}

struct PassbookCondition: OperationCondition
{
    static let name = "Passbook"
    static let isMutuallyExclusive = false
    
    init() {}
    
    func dependency(for operation: BaseOperation) -> Operation?
    {
        return nil
    }
    
    func evaluate(for operation: BaseOperation, completion: @escaping (OperationConditionResult) -> ())
    {
        if PKPassLibrary.isPassLibraryAvailable()
        {
            completion(.satisfied)
        }
        else
        {
            let error = NSError(code: .conditionFailed, userInfo: [OperationConditionKey: type(of: self).name])
            completion(.failed(error))
        }
    }
}

struct LocationCondition: OperationCondition
{
    enum Usage
    {
        case whenInUse
        case always
    }
    
    static let name = "Location"
    static let locationServicesEnabledKey = "CLLocationServicesEnabled"
    static let authorizationStatusKey = "CLAuthorizationStatus"
    static let isMutuallyExclusive = false
    
    let usage: Usage
    
    init(usage: Usage)
    {
        self.usage = usage
    }
    
    func dependency(for operation: BaseOperation) -> Operation?
    {
        return LocationPermissionOperation(usage: usage)
    }
    
    func evaluate(for operation: BaseOperation, completion: @escaping (OperationConditionResult) -> ())
    {
        let enabled = CLLocationManager.locationServicesEnabled()
        let actual = CLLocationManager.authorizationStatus()
        var error: NSError?
        
        switch (enabled, usage, actual)
        {
        case (true, _, .authorizedAlways):
            break
        case (true, .whenInUse, .authorizedWhenInUse):
            break
        default:
            error = NSError(code: .conditionFailed, userInfo: [OperationConditionKey: type(of: self).name,
                                                               type(of: self).locationServicesEnabledKey: enabled
                ,
                                                               type(of: self).authorizationStatusKey: Int(actual.rawValue)])
        }
        if let error = error
        {
            completion(.failed(error))
        }
        else
        {
            completion(.satisfied)
        }
    }
}

fileprivate class LocationPermissionOperation: BaseOperation
{
    let usage: LocationCondition.Usage
    var manager: CLLocationManager?
    
    init(usage: LocationCondition.Usage)
    {
        self.usage = usage
        super.init()
        add(AlertPresentation())
    }
    
    override func execute()
    {
        switch(CLLocationManager.authorizationStatus(), usage)
        {
        case(.notDetermined, _), (.authorizedWhenInUse, .always):
            DispatchQueue.main.async
                {
                    self.requestPermission()
            }
        default:
            finish()
        }
    }
    
    fileprivate func requestPermission()
    {
        manager = CLLocationManager()
        manager?.delegate = self
        
        let key: String
        
        switch usage
        {
        case .whenInUse:
            key = "NSLocationWhenInUseUsageDescription"
            manager?.requestWhenInUseAuthorization()
            
        case .always:
            key = "NSLocationAlwaysUsageDescription"
            manager?.requestAlwaysAuthorization()
        }
        
        assert(Bundle.main.object(forInfoDictionaryKey: key) != nil, "Requesting location permission requires the \(key) key in your Info.plist")
    }
}

extension LocationPermissionOperation: CLLocationManagerDelegate
{
    @objc func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus)
    {
        if manager == self.manager && isExecuting && status != .notDetermined
        {
            finish()
        }
    }
}

struct CalendarCondition: OperationCondition
{
    static let name = "Calendar"
    static let entityTypeKey = "EKEntityType"
    static let isMutuallyExclusive = false
    
    let entityType: EKEntityType
    
    init(entityType: EKEntityType)
    {
        self.entityType = entityType
    }
    
    func dependency(for operation: BaseOperation) -> Operation?
    {
        return CalendarPermissionOperation(entityType: entityType)
    }
    
    func evaluate(for operation: BaseOperation, completion: @escaping (OperationConditionResult) -> ())
    {
        switch EKEventStore.authorizationStatus(for: entityType)
        {
        case .authorized:
            completion(.satisfied)
        default:
            let error = NSError(code: .conditionFailed, userInfo: [OperationConditionKey: type(of: self).name,
                                                                   type(of: self).entityTypeKey: entityType.rawValue])
            completion(.failed(error))
        }
    }
}

fileprivate let SharedEventStore = EKEventStore()

fileprivate class CalendarPermissionOperation: BaseOperation
{
    let entityType: EKEntityType
    
    init(entityType: EKEntityType)
    {
        self.entityType = entityType
        super.init()
        self.add(AlertPresentation())
    }
    
    override func execute()
    {
        let status = EKEventStore.authorizationStatus(for: entityType)
        switch status
        {
        case .notDetermined:
            DispatchQueue.main.async
            {
                SharedEventStore.requestAccess(to: self.entityType)
                { (granted, error) in
                    self.finish()
                }
            }
        default:
            finish()
        }
    }
}

struct PhotosCondition: OperationCondition
{
    static let name = "Photos"
    static let isMutuallyExclusive = false
    
    init() {}
    
    func dependency(for operation: BaseOperation) -> Operation?
    {
        return PhotosPermissionOperation()
    }
    
    func evaluate(for operation: BaseOperation, completion: @escaping (OperationConditionResult) -> ())
    {
        switch PHPhotoLibrary.authorizationStatus()
        {
        case .authorized:
            completion(.satisfied)
        default:
            let error = NSError(code: .conditionFailed, userInfo: [OperationConditionKey: type(of: self).name])
            completion(.failed(error))
        }
    }
}

fileprivate class PhotosPermissionOperation: BaseOperation
{
    override init()
    {
        super.init()
        add(AlertPresentation())
    }
    
    override func execute()
    {
        switch PHPhotoLibrary.authorizationStatus()
        {
        case .notDetermined:
            DispatchQueue.main.async
            {
                PHPhotoLibrary.requestAuthorization
                { (_) in
                    self.finish()
                }
            }
        default:
            finish()
        }
    }
}

struct HealthCondition: OperationCondition
{
    static let name = "Health"
    static let healthDataAvailable = "HealthDataAvailable"
    static let unauthorizedShareTypeKey = "UnathorizedShareTypes"
    static let isMutuallyExclusive = false
    
    let shareTypes: Set<HKSampleType>
    let readTypes: Set<HKSampleType>
    
    init(typesToWrite: Set<HKSampleType>, typesToRead: Set<HKSampleType>)
    {
        shareTypes = typesToWrite
        readTypes = typesToRead
    }
    
    func dependency(for operation: BaseOperation) -> Operation?
    {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        guard !shareTypes.isEmpty || !readTypes.isEmpty else { return nil }
        
        return HealthPermissionOperation(shareTypes: shareTypes, readTypes: readTypes)
    }
    
    func evaluate(for operation: BaseOperation, completion: @escaping (OperationConditionResult) -> ())
    {
        guard HKHealthStore.isHealthDataAvailable() else
        {
            failed(shareTypes, completion: completion)
            return
        }
        let store = HKHealthStore()
        
        let unauthorizedShareTypes = shareTypes.filter
        { shareType in
            return store.authorizationStatus(for: shareType) != .sharingAuthorized
        }
        
        if !unauthorizedShareTypes.isEmpty
        {
            failed(Set(unauthorizedShareTypes), completion: completion)
        }
        else
        {
            completion(.satisfied)
        }
    }
    
    fileprivate func failed(_ unauthorizedShareTypes: Set<HKSampleType>, completion: (OperationConditionResult) -> ())
    {
        let error = NSError(code: .conditionFailed, userInfo: [
            OperationConditionKey: type(of: self).name,
            type(of: self).healthDataAvailable: HKHealthStore.isHealthDataAvailable(),
            type(of: self).unauthorizedShareTypeKey: unauthorizedShareTypes
            ])
        completion(.failed(error))
    }
}

fileprivate class HealthPermissionOperation: BaseOperation
{
    let shareTypes: Set<HKSampleType>
    let readTypes: Set<HKSampleType>
    
    init(shareTypes: Set<HKSampleType>, readTypes: Set<HKSampleType>)
    {
        self.shareTypes = shareTypes
        self.readTypes = readTypes
        
        super.init()
        
        add(MutuallyExclusive<HealthPermissionOperation>())
        add(MutuallyExclusive<UIViewController>())
        add(AlertPresentation())
    }
    
    override func execute() {
        DispatchQueue.main.async
        {
            let store = HKHealthStore()
            store.requestAuthorization(toShare: self.shareTypes, read: self.readTypes)
            { (_, _) in
                self.finish()
            }
        }
    }
}

fileprivate let RemoteNotificationQueue = BaseOperationQueue()
fileprivate let RemoteNotificationName = "RemoteNotificationPermissionNotification"

fileprivate enum RemoteRegistrationResult
{
    case token(Data)
    case error(NSError)
}

struct RemoteNotificationCondition: OperationCondition
{
    static let name = "RemoteNotification"
    static let isMutuallyExclusive = false
    
    static func didReceiveNotificationToken(_ token: Data)
    {
        NotificationCenter.default.post(name: Notification.Name(RemoteNotificationName), object: nil, userInfo: ["token": token])
        
    }
    
    static func didFailToRegister(_ error: NSError)
    {
        NotificationCenter.default.post(name: Notification.Name(RemoteNotificationName), object: nil, userInfo: ["error": error])
    }
    
    let application: UIApplication
    
    init(application: UIApplication)
    {
        self.application = application
    }
    
    func dependency(for operation: BaseOperation) -> Operation?
    {
        return RemoteNotificationPermissionOperation(application: application, handler: { (_) in })
    }
    
    func evaluate(for operation: BaseOperation, completion: @escaping (OperationConditionResult) -> ())
    {
        RemoteNotificationQueue.addOperation(RemoteNotificationPermissionOperation(application: application)
        { (result) in
            switch result
            {
            case .token:
                completion(.satisfied)
            case .error(let underlyingError):
                let error = NSError(code: .conditionFailed, userInfo: [
                    OperationConditionKey: type(of: self).name,
                    NSUnderlyingErrorKey: underlyingError
                    ])
                completion(.failed(error))
            }
        })
    }
}

fileprivate class RemoteNotificationPermissionOperation: BaseOperation
{
    let application: UIApplication
    fileprivate let handler: (RemoteRegistrationResult) -> ()
    
    fileprivate init(application: UIApplication, handler: @escaping (RemoteRegistrationResult) -> ())
    {
        self.application = application
        self.handler = handler
        
        super.init()
        add(MutuallyExclusive<RemoteNotificationPermissionOperation>())
    }
    
    @objc func didReceiveResponse(_ notification: Notification)
    {
        NotificationCenter.default.removeObserver(self)
        let userInfo = notification.userInfo
        if let token = userInfo?["token"] as? Data
        {
            handler(.token(token))
        }
        else if let error = userInfo?["error"] as? NSError
        {
            handler(.error(error))
        }
        else
        {
            fatalError("Received a notification without a token and without an error.")
        }
        finish()
    }
}

struct UserNotificationCondition: OperationCondition
{
    enum Behavior
    {
        case merge
        case replace
    }
    
    static let name = "UserNotification"
    static let currentSettings = "CurrentUserNotificationSettings"
    static let desiredSettings = "DesiredUserNotificationSettings"
    static let isMutuallyExclusive = false
    
    let settings: UIUserNotificationSettings
    let application: UIApplication
    let behavior: Behavior
    
    init(settings: UIUserNotificationSettings, application: UIApplication, behavior: Behavior = .merge)
    {
        self.settings = settings
        self.application = application
        self.behavior = behavior
    }
    
    func dependency(for operation: BaseOperation) -> Operation?
    {
        return UserNotificationPermissionOperation(settings: settings, application: application, behavior: behavior)
    }
    
    func evaluate(for operation: BaseOperation, completion: @escaping (OperationConditionResult) -> ())
    {
        let result: OperationConditionResult
        let current = application.currentUserNotificationSettings
        
        switch (current, settings)
        {
        case (let current?, let settings) where current.contains(settings):
            result = .satisfied
        default:
            let error = NSError(code: .conditionFailed, userInfo: [
                OperationConditionKey: type(of: self).name,
                type(of: self).currentSettings: current ?? NSNull(),
                type(of: self).desiredSettings: settings
                ])
            result = .failed(error)
        }
        
        completion(result)
    }
}

fileprivate class UserNotificationPermissionOperation: BaseOperation
{
    let settings: UIUserNotificationSettings
    let application: UIApplication
    let behavior: UserNotificationCondition.Behavior
    
    init(settings: UIUserNotificationSettings, application: UIApplication, behavior: UserNotificationCondition.Behavior)
    {
        self.settings = settings
        self.application = application
        self.behavior = behavior
        
        super.init()
        
        add(AlertPresentation())
    }
    
    override func execute()
    {
        DispatchQueue.main.async
        {
            let current = self.application.currentUserNotificationSettings
            let settingsToRegister: UIUserNotificationSettings
            
            switch (current, self.behavior)
            {
            case(let currentSettings?, .merge):
                settingsToRegister = currentSettings.settingsByMerging(self.settings)
            default:
                settingsToRegister = self.settings
            }
            self.application.registerUserNotificationSettings(settingsToRegister)
        }
    }
}

// MARK: - Extensions
// MARK: -
extension NSLock
{
    func withCriticalScope<T>(_ block: @escaping () -> T) -> T
    {
        lock()
        let value = block
        unlock()
        return value()
    }
}

let OperationErrorDomain = "OperationErrors"

enum OperationErrorCode: Int {
    case conditionFailed = 1
    case executionFailed = 2
}

extension NSError
{
    convenience init(code: OperationErrorCode, userInfo: [AnyHashable: Any]? = nil)
    {
        self.init(domain: OperationErrorDomain, code: code.rawValue, userInfo: userInfo as! [String : Any])
    }
}

extension CKContainer
{
    func verify(_ permission: CKApplicationPermissions, request shouldRequest: Bool, completion: @escaping (NSError?) ->())
    {
        verifyAccountStatus(self, permission: permission, shouldRequest: shouldRequest, completion: completion)
    }
}

fileprivate func verifyAccountStatus(_ container: CKContainer, permission: CKApplicationPermissions, shouldRequest: Bool, completion: @escaping (NSError?) -> ())
{
    container.accountStatus
        { (accountStatus, error) in
            if accountStatus == .available
            {
                if permission != []
                {
                    verifyPermission(container, permission: permission, shouldRequest: shouldRequest
                        , completion: completion)
                }
                else
                {
                    completion(nil)
                }
            }
            else
            {
                let error = error ?? NSError(domain: CKErrorDomain, code: CKError.notAuthenticated.rawValue, userInfo: nil)
                completion(error as NSError)
            }
    }
}

fileprivate func verifyPermission(_ container: CKContainer, permission: CKApplicationPermissions, shouldRequest: Bool, completion: @escaping (NSError?) -> Void)
{
    container.status(forApplicationPermission: permission)
    { permissionStatus, permissionError in
        if permissionStatus == .granted
        {
            completion(nil)
        }
        else if permissionStatus == .initialState && shouldRequest
        {
            requestPermission(container, permission: permission, completion: completion)
        }
        else
        {
            let error = permissionError ?? NSError(domain: CKErrorDomain, code: CKError.permissionFailure.rawValue, userInfo: nil)
            completion(error as NSError)
        }
    }
}

fileprivate func requestPermission(_ container: CKContainer, permission: CKApplicationPermissions, completion: @escaping (NSError?) -> Void)
{
    DispatchQueue.main.async
        {
            container.requestApplicationPermission(permission)
            { requestStatus, requestError in
                if requestStatus == .granted
                {
                    completion(nil)
                }
                else
                {
                    let error = requestError ?? NSError(domain: CKErrorDomain, code: CKError.permissionFailure.rawValue, userInfo: nil)
                    completion(error as NSError)
                }
            }
    }
}


// This makes it easy to compare an `NSError.code` to an `OperationErrorCode`.
func ==(lhs: Int, rhs: OperationErrorCode) -> Bool
{
    return lhs == rhs.rawValue
}

func ==(lhs: OperationErrorCode, rhs: Int) -> Bool
{
    return lhs.rawValue == rhs
}


extension UIUserNotificationSettings
{
    func contains(_ settings: UIUserNotificationSettings) -> Bool
    {
        if !types.contains(settings.types)
        {
            return false
        }
        
        let otherCategories = settings.categories ?? []
        let myCategories = categories ?? []
        
        return myCategories.isSuperset(of: otherCategories)
    }
    
    func settingsByMerging(_ settings: UIUserNotificationSettings) -> UIUserNotificationSettings
    {
        let mergedTypes = types.union(settings.types)
        
        let myCategories = categories ?? []
        var existingCategoriesByIdentifier: [String: UIUserNotificationCategory] = myCategories.reduce([:])
        { (result, category) in
            var result = result
            result[category.identifier ?? ""] = category
            return result
        }
        
        let newCategories = settings.categories ?? []
        var newCategoriesByIdentifier: [String: UIUserNotificationCategory] = newCategories.reduce([:])
        { (result, category) in
            var result = result
            result[category.identifier ?? ""] = category
            return result
        }
        
        for (newIdentifier, newCategory) in newCategoriesByIdentifier
        {
            existingCategoriesByIdentifier[newIdentifier] = newCategory
        }
        
        let mergedCategories = Set(existingCategoriesByIdentifier.values)
        return UIUserNotificationSettings(types: mergedTypes, categories: mergedCategories)
    }
}
