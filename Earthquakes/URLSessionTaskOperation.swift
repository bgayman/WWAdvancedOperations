//
//  URLSessionTaskOperation.swift
//  Earthquakes
//
//  Created by App Partner on 6/27/17.
//  Copyright © 2017 App Partner. All rights reserved.
//

import Foundation

fileprivate var URLSessionTaskOperationKVOContext = 0

class URLSessionTaskOperation: BaseOperation
{
    let task: URLSessionTask
    
    init(task: URLSessionTask)
    {
        assert(task.state == .suspended, "Tasks must be suspended.")
        self.task = task
        super.init()
    }
    
    override func execute()
    {
        assert(task.state == .suspended, "Task was resumed by something other than \(self).")
        task.addObserver(self, forKeyPath: "state", options: [], context: &URLSessionTaskOperationKVOContext)
        task.resume()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?)
    {
        guard context == &URLSessionTaskOperationKVOContext,
            let object = object as? URLSessionTask else { return }
        if object === task && keyPath == "state" && task.state == .completed
        {
            task.removeObserver(self, forKeyPath: "state")
            finish()
        }
    }
    
    override func cancel()
    {
        task.cancel()
        super.cancel()
    }
}
