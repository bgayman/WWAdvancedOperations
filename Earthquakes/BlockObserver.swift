//
//  BlockObserver.swift
//  Earthquakes
//
//  Created by App Partner on 6/27/17.
//  Copyright © 2017 App Partner. All rights reserved.
//

import Foundation

struct BlockObserver: OperationObserver
{
    fileprivate let startHandler: ((BaseOperation) -> ())?
    fileprivate let produceHandler: ((BaseOperation, Operation) ->  ())?
    fileprivate let finishHandler: ((BaseOperation, [NSError]) -> ())?
    
    init(startHandler: ((BaseOperation) -> ())? = nil, produceHandler: ((BaseOperation, Operation) -> ())? = nil, finishHandler: ((BaseOperation, [NSError]) -> ())? = nil)
    {
        self.startHandler = startHandler
        self.produceHandler = produceHandler
        self.finishHandler = finishHandler
    }
    
    func operation(didStart operation: BaseOperation)
    {
        startHandler?(operation)
    }
    
    func operation(_ operation: BaseOperation, didProduce newOperation: Operation)
    {
        produceHandler?(operation, newOperation)
    }
    
    func operation(didFinish operation: BaseOperation, errors: [NSError])
    {
        finishHandler?(operation, errors)
    }
}
