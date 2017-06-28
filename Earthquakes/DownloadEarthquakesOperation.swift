//
//  DownloadEarthquakesOperation.swift
//  Earthquakes
//
//  Created by App Partner on 6/23/17.
//  Copyright © 2017 App Partner. All rights reserved.
//

import Foundation
import UIKit

class DownloadEarthquakesOperation: GroupOperation
{
    let cacheFile: URL
    
    init(cacheFile: URL)
    {
        self.cacheFile = cacheFile
        super.init(operations: [])
        name = "Download Earthquakes"
        
        let url = URL(string: "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/2.5_month.geojson")!
        let task = URLSession.shared.downloadTask(with: url)
        { (url, response, error) in
            self.downloadFinished(url, response: response as? HTTPURLResponse, error: error as NSError?)
        }
        let taskOperation = URLSessionTaskOperation(task: task)
        let reachabilityCondition = ReachabilityCondition(host: url)
        taskOperation.add(reachabilityCondition)
        let networkObserver = NetworkObserver()
        add(networkObserver)
        add(taskOperation)
    }
    
    func downloadFinished(_ url: URL?, response: HTTPURLResponse?, error: NSError?)
    {
        if let localURL = url
        {
            try? FileManager.default.removeItem(at: cacheFile)
            
            do
            {
                try FileManager.default.moveItem(at: localURL, to: cacheFile)
            }
            catch let error as NSError
            {
                aggregate(error)
            }
        }
        else if let error = error
        {
            aggregate(error)
        }
    }
}

struct NetworkObserver: OperationObserver
{
    init(){}
    
    func operation(didStart operation: BaseOperation)
    {
        DispatchQueue.main.async
        {
            NetworkIndicatorController.sharedIndicatorController.networkActivityDidStart()
        }
    }
    
    func operation(_ operation: BaseOperation, didProduce newOperation: Operation) {}
    
    func operation(didFinish operation: BaseOperation, errors: [NSError])
    {
        DispatchQueue.main.async
        {
            NetworkIndicatorController.sharedIndicatorController.networkActivityDidEnd()
        }
    }
}

private class NetworkIndicatorController
{
    static let sharedIndicatorController = NetworkIndicatorController()
    
    fileprivate var activityCount = 0
    fileprivate var visibilityTimer: Delay?
    
    func networkActivityDidStart()
    {
        assert(Thread.isMainThread, "Altering network activity indicator state can only be done on the main thread.")
        activityCount += 1
        updateIndicatorVisibility()
    }
    
    func networkActivityDidEnd()
    {
        assert(Thread.isMainThread, "Altering network activity indicator state can only be done on the main thread.")
        activityCount -= 1
        updateIndicatorVisibility()
    }
    
    fileprivate func updateIndicatorVisibility()
    {
        if activityCount > 0
        {
            showIndicator()
        }
        else
        {
            visibilityTimer = Delay(interval: 1.0)
            {
                self.hideIndicator()
            }
        }
    }
    
    fileprivate func showIndicator()
    {
        visibilityTimer?.cancel()
        visibilityTimer = nil
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
    }
    
    fileprivate func hideIndicator()
    {
        visibilityTimer?.cancel()
        visibilityTimer = nil
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
}

class Delay
{
    fileprivate var isCancelled = false
    
    init(interval: TimeInterval, handler: @escaping () ->())
    {
        let when = DispatchTime.now() + Double(Int64(interval * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        
        DispatchQueue.main.asyncAfter(deadline: when)
        { [weak self] in
            if self?.isCancelled == false
            {
                handler()
            }
        }
    }
    
    func cancel()
    {
        isCancelled = true
    }
}




