//
//  DelayOperation.swift
//  Earthquakes
//
//  Created by App Partner on 6/27/17.
//  Copyright © 2017 App Partner. All rights reserved.
//

import Foundation

class DelayOperation: BaseOperation
{
    fileprivate enum Delay
    {
        case interval(TimeInterval)
        case date(Date)
    }
    
    fileprivate let delay: Delay
    
    init(interval: TimeInterval)
    {
        delay = .interval(interval)
        super.init()
    }
    
    init(until date: Date)
    {
        delay = .date(date)
        super.init()
    }
    
    override func execute()
    {
        let interval: TimeInterval
        
        switch delay
        {
        case .interval(let theInterval):
            interval = theInterval
        case .date(let date):
            interval = date.timeIntervalSinceNow
        }
        
        guard interval > 0 else
        {
            finish()
            return
        }
        
        let when = DispatchTime.now() + Double(Int64(interval * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.global().asyncAfter(deadline: when)
        {
            if !self.isCancelled
            {
                self.finish()
            }
        }
    }
    
    override func cancel()
    {
        super.cancel()
        self.finish()
    }
}
