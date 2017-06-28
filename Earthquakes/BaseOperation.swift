//
//  BlockObserver.swift
//  Earthquakes
//
//  Created by App Partner on 6/21/17.
//  Copyright © 2017 App Partner. All rights reserved.
//

import Foundation

// MARK: - BaseOperation
class BaseOperation: Operation
{
    class func keyPathsForValuesAffectingIsReady() -> Set<NSObject>
    {
        return ["state" as NSObject]
    }
    
    class func keyPathsForValuesAffectingIsExecuting() -> Set<NSObject>
    {
        return ["state" as NSObject]
    }
    
    class func keyPathsForValuesAffectingIsFinished() -> Set<NSObject>
    {
        return ["state" as NSObject]
    }
    
    fileprivate enum State: Int
    {
        case initialized
        case pending
        case evaluatingConditions
        case ready
        case executing
        case finishing
        case finished
        
        func canTransitionToState(_ target: State) -> Bool
        {
            switch (self, target)
            {
            case (.initialized, .pending):
                return true
            case (.pending, .evaluatingConditions):
                return true
            case (.evaluatingConditions, .ready):
                return true
            case (.ready, .executing):
                return true
            case (.ready, .finishing):
                return true
            case (.executing, .finishing):
                return true
            case (.finishing, .finished):
                return true
            default:
                return false
            }
        }
    }
    
    func willEnqueue()
    {
        state = .pending
    }
    
    fileprivate var _state = State.initialized
    
    fileprivate let stateLock = NSLock()
    
    fileprivate var state: State
    {
        get
        {
            return stateLock.withCriticalScope { self._state }
        }
        
        set(newState)
        {
            willChangeValue(forKey: "state")
            stateLock.withCriticalScope
            { () -> () in
                guard self._state != .finished else { return }
                assert(self._state.canTransitionToState(newState), "Performing invalid state transition.")
                self._state = newState
            }
            didChangeValue(forKey: "state")
        }
    }
    
    override var isReady: Bool
    {
        switch state
        {
        case .initialized:
            return isCancelled
        case .pending:
            guard !isCancelled else { return true }
            if super.isReady
            {
                evaluateConditions()
            }
            return false
        case .ready:
            return super.isReady || isCancelled
        default:
            return false
        }
    }
    
    var userInitiated: Bool
    {
        get
        {
            return qualityOfService == .userInitiated
        }
        
        set
        {
            assert(state < .executing, "Cannot modify userInitiated after execution has begun.")
            qualityOfService = newValue ? .userInitiated : .default
        }
    }
    
    override var isExecuting: Bool
    {
        return state == .executing
    }
    
    override var isFinished: Bool
    {
        return state == .finished
    }
    
    fileprivate func evaluateConditions()
    {
        assert(state == .pending && !isCancelled, "evaluateConditions() was called out-of-order")
        
        state = .evaluatingConditions
        
        OperationConditionEvaluator.evaluate(conditions, operation: self)
        { (failures) in
            self._internalErrors.append(contentsOf: failures)
            self.state = .ready
        }
    }
    
    fileprivate(set) var conditions = [OperationCondition]()
    
    func add(_ condition: OperationCondition)
    {
        assert(state < .evaluatingConditions, "Cannot modify conditions after execution has begun.")
        conditions.append(condition)
    }
    
    fileprivate(set) var observers = [OperationObserver]()
    
    func add(_ observer: OperationObserver)
    {
        assert(state < .executing, "Cannot modify observers after execution has begun.")
        observers.append(observer)
    }
    
    override func addDependency(_ op: Operation)
    {
        assert(state < .executing, "Dependencies cannot be modified after execution has begun.")
        super.addDependency(op)
    }
    
    override final func main()
    {
        assert(state == .ready, "This operation must be performed on an operation queue.")
        
        if _internalErrors.isEmpty && !isCancelled
        {
            state = .executing
            for observer in observers
            {
                observer.operation(didStart: self)
            }
            
            execute()
        }
        else
        {
            finish()
        }
    }
    
    func execute()
    {
        print("\(type(of: self)) must override `execute()`.")
        finish()
    }
    
    fileprivate var _internalErrors = [NSError]()
    func cancel(with error: NSError? = nil)
    {
        if let error = error
        {
            _internalErrors.append(error)
        }
        
        cancel()
    }
    
    final func produceOperation(_ operation: Operation)
    {
        for observer in observers
        {
            observer.operation(self, didProduce: operation)
        }
    }
    
    final func finishWithError(_ error: NSError?)
    {
        if let error = error
        {
            finish([error])
        }
        else
        {
            finish()
        }
    }
    
    fileprivate var hasFinishedAlready = false
    final func finish(_ errors: [NSError] = [])
    {
        if !hasFinishedAlready
        {
            hasFinishedAlready = true
            state = .finishing
            
            let combinedErrors = _internalErrors + errors
            finished(combinedErrors)
            for observer in observers
            {
                observer.operation(didFinish: self, errors: combinedErrors)
            }
            
            state = .finished
        }
    }
    
    func finished(_ errors: [NSError])
    {
        
    }
    
    override final func waitUntilFinished()
    {
        fatalError("Waiting on operations is an anti-pattern. Remove this ONLY if you're absolutely sure there is No Other Way™.")
    }
}

enum OperationConditionResult
{
    case satisfied
    case failed(NSError)
    
    var error: NSError?
    {
        if case .failed(let error) = self
        {
            return error
        }
        return nil
    }
}

extension OperationConditionResult: Equatable
{
    static func ==(lhs: OperationConditionResult, rhs: OperationConditionResult) -> Bool
    {
        switch (lhs, rhs)
        {
        case (.satisfied, .satisfied):
            return true
        case (.failed(let lError), .failed(let rError)) where lError == rError:
            return true
        default:
            return false
        }
    }
}

extension BaseOperation.State: Comparable
{
    static func <(lhs: BaseOperation.State, rhs: BaseOperation.State) -> Bool
    {
        return lhs.rawValue < rhs.rawValue
    }
    
    static func ==(lhs: BaseOperation.State, rhs: BaseOperation.State) -> Bool
    {
        return lhs.rawValue == rhs.rawValue
    }
}






