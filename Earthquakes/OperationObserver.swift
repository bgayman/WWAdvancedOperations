//
//  OperationObserver.swift
//  Earthquakes
//
//  Created by App Partner on 6/27/17.
//  Copyright © 2017 App Partner. All rights reserved.
//

import Foundation

// MARK: - Observer
protocol OperationObserver
{
    func operation(didStart operation: BaseOperation)
    func operation(_ operation: BaseOperation, didProduce newOperation: Operation)
    func operation(didFinish operation: BaseOperation, errors: [NSError])
}
