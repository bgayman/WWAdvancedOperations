//
//  GroupOperation.swift
//  Earthquakes
//
//  Created by App Partner on 6/27/17.
//  Copyright © 2017 App Partner. All rights reserved.
//

import Foundation

class GroupOperation: BaseOperation
{
    fileprivate let internalQueue = BaseOperationQueue()
    fileprivate let startingOperation = BlockOperation(block: {})
    fileprivate let finishingOperation = BlockOperation(block: {})
    
    fileprivate var aggregatedErrors = [NSError]()
    
    convenience init(operations: Operation...)
    {
        self.init(operations: operations)
    }
    
    init(operations: [Operation])
    {
        super.init()
        
        internalQueue.isSuspended = true
        internalQueue.delegate = self
        internalQueue.addOperation(startingOperation)
        
        for operation in operations
        {
            internalQueue.addOperation(operation)
        }
    }
    
    override func cancel()
    {
        internalQueue.cancelAllOperations()
        super.cancel()
    }
    
    override func execute()
    {
        internalQueue.isSuspended = false
        internalQueue.addOperation(finishingOperation)
    }
    
    func add(_ operation: Operation)
    {
        internalQueue.addOperation(operation)
    }
    
    final func aggregate(_ error: NSError)
    {
        aggregatedErrors.append(error)
    }
    
    func operationDidFinish(_ operation: Operation, with errors: [NSError])
    {
        
    }
}

extension GroupOperation: BaseOperationQueueDelegate
{
    func operationQueue(_ operationQueue: BaseOperationQueue, willAdd operation: Operation)
    {
        assert(!finishingOperation.isFinished && !finishingOperation.isExecuting, "cannot add new operations to a group after the group has completed")
        
        if operation !== finishingOperation
        {
            finishingOperation.addDependency(operation)
        }
        
        if operation !== startingOperation
        {
            operation.addDependency(startingOperation)
        }
    }
    
    final func operationQueue(_ operationQueue: BaseOperationQueue, didFinish operation: Operation, with errors: [NSError])
    {
        aggregatedErrors.append(contentsOf: errors)
        if operation === finishingOperation
        {
            internalQueue.isSuspended = true
            finish(aggregatedErrors)
        }
        else if operation !== startingOperation
        {
            operationDidFinish(operation, with: errors)
        }
    }
}
