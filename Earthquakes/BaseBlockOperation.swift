//
//  BaseBlockOperation.swift
//  Earthquakes
//
//  Created by App Partner on 6/27/17.
//  Copyright © 2017 App Partner. All rights reserved.
//

import Foundation

typealias OperationBlock = ( @escaping (Void) -> Void) -> Void

class BaseBlockOperation: BaseOperation
{
    fileprivate let block: OperationBlock?
    
    init(block: OperationBlock? = nil)
    {
        self.block = block
        super.init()
    }
    
    convenience init(mainQueueBlock: @escaping () ->())
    {
        self.init(block:
        { (continuation) in
            DispatchQueue.main.async
                {
                    mainQueueBlock()
                    continuation()
            }
        })
    }
    
    override func execute()
    {
        guard let block = block else
        {
            finish()
            return
        }
        
        block
        {
            self.finish()
        }
    }
}
