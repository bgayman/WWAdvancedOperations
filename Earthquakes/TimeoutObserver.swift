//
//  TimeoutObserver.swift
//  Earthquakes
//
//  Created by App Partner on 6/27/17.
//  Copyright © 2017 App Partner. All rights reserved.
//

import Foundation

struct TimeoutObserver: OperationObserver
{
    static let timeoutKey = "Timeout"
    fileprivate let timeout: TimeInterval
    
    init(timeout: TimeInterval)
    {
        self.timeout = timeout
    }
    
    func operation(didStart operation: BaseOperation)
    {
        let when = DispatchTime.now() + DispatchTimeInterval.seconds(Int(timeout))
        
        DispatchQueue.global().asyncAfter(deadline: when)
        {
            if !operation.isFinished && !operation.isCancelled
            {
                let error = NSError(code: .executionFailed, userInfo: [type(of: self).timeoutKey: self.timeout])
                operation.cancel(with: error)
            }
        }
    }
    
    func operation(_ operation: BaseOperation, didProduce newOperation: Operation) {}
    
    func operation(didFinish operation: BaseOperation, errors: [NSError]) {}
}
