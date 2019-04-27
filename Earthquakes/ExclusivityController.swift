//
//  ExclusivityController.swift
//  Earthquakes
//
//  Created by App Partner on 6/27/17.
//  Copyright © 2017 App Partner. All rights reserved.
//

import Foundation

class ExclusivityController
{
    static let shared = ExclusivityController()
    
    fileprivate let serialQueue = DispatchQueue(label: "Operations.ExeclusivityController")
    fileprivate var operations: [String: [BaseOperation]] = [:]
    
    fileprivate init() {}
    
    func add(_ operation: BaseOperation, categories: [String])
    {
        serialQueue.sync
        {
            for category in categories
            {
                self.noqueue_add(operation, category: category)
            }
        }
    }
    
    func remove(_ operation: BaseOperation, categories: [String])
    {
        serialQueue.async
        {
            for category in categories
            {
                self.noqueue_removeOperation(operation, category: category)
            }
        }
    }
    
    fileprivate func noqueue_add(_ operation: BaseOperation, category: String)
    {
        var operationsWithThisCategory = operations[category] ?? []
        
        if let last = operationsWithThisCategory.last
        {
            operation.addDependency(last)
        }
        
        operationsWithThisCategory.append(operation)
        operations[category] = operationsWithThisCategory
    }
    
    fileprivate func noqueue_removeOperation(_ operation: BaseOperation, category: String)
    {
        let matchingOperations = operations[category]
        
        if var operationsWithThisCategory = matchingOperations,
            let index = operationsWithThisCategory.firstIndex(of: operation)
        {
            operationsWithThisCategory.remove(at: index)
            operations[category] = operationsWithThisCategory
        }
    }
}
