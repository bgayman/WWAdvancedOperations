//
//  BaseOperationQueue.swift
//  Earthquakes
//
//  Created by App Partner on 6/21/17.
//  Copyright © 2017 App Partner. All rights reserved.
//

import Foundation

@objc protocol BaseOperationQueueDelegate: NSObjectProtocol
{
    @objc optional func operationQueue(_ operationQueue: BaseOperationQueue, willAdd operation: Operation)
    @objc optional func operationQueue(_ operationQueue: BaseOperationQueue, didFinish operation: Operation, with errors: [NSError])
}

class BaseOperationQueue: OperationQueue
{
    weak var delegate: BaseOperationQueueDelegate?
    
    override func addOperation(_ op: Operation)
    {
        if let op = op as? BaseOperation
        {
            let delegate = BlockObserver(startHandler: nil,
                                         produceHandler: { [weak self] in
                                            self?.addOperation($1)
                },
                                         finishHandler: { [weak self] in
                                            if let q = self
                                            {
                                                q.delegate?.operationQueue?(q, didFinish: $0, with: $1)
                                            }
            })
            
            op.add(delegate)
            
            let dependencies = op.conditions.compactMap  { $0.dependency(for: op) }
            
            for dependency in dependencies
            {
                op.addDependency(dependency)
                self.addOperation(dependency)
            }
            
            let concurrencyCategories: [String] = op.conditions.compactMap
            { condition in
                guard type(of: condition).isMutuallyExclusive else { return nil }
                return "\(type(of: condition))"
            }
            
            if !concurrencyCategories.isEmpty
            {
                let exclusivityController = ExclusivityController.shared
                exclusivityController.add(op, categories: concurrencyCategories)
                let blockObserver = BlockObserver(startHandler: nil, produceHandler: nil)
                { (operation, _) in
                    exclusivityController.remove(operation, categories: concurrencyCategories)
                }
                op.add(blockObserver)
            }
            op.willEnqueue()
        }
        else
        {
            op.completionBlock =
            { [weak self, weak op] in
                guard let queue = self, let operation = op else { return }
                queue.delegate?.operationQueue?(queue, didFinish: operation, with: [])
            }
        }
        delegate?.operationQueue?(self, willAdd: op)
        super.addOperation(op)
    }
    
    override func addOperations(_ ops: [Operation], waitUntilFinished wait: Bool)
    {
        for op in ops
        {
            addOperation(op)
        }
        
        
        if wait
        {
            for op in ops
            {
                op.waitUntilFinished()
            }
        }
    }
}
