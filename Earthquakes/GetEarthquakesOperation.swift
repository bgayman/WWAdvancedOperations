//
//  GetEarthquakesOperation.swift
//  Earthquakes
//
//  Created by App Partner on 6/23/17.
//  Copyright © 2017 App Partner. All rights reserved.
//

import CoreData

class GetEarthquakesOperation: GroupOperation
{
    let downloadOperation: DownloadEarthquakesOperation
    let parseOperation: ParseEarthquakesOperation
    
    fileprivate var hasProducedAlert = false
    
    init(context: NSManagedObjectContext, completionHandler: @escaping () -> ())
    {
        let cachesFolder = try! FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let cacheFile = cachesFolder.appendingPathComponent("earthquakes.json")
        
        downloadOperation = DownloadEarthquakesOperation(cacheFile: cacheFile)
        parseOperation = ParseEarthquakesOperation(cacheFile: cacheFile, context: context)
        
        let finishOperation = BlockOperation(block: completionHandler)
        
        parseOperation.addDependency(downloadOperation)
        finishOperation.addDependency(parseOperation)
        
        super.init(operations: [downloadOperation, parseOperation, finishOperation])
        
        name = "Get Earthquakes"
    }
    
    override func operationDidFinish(_ operation: Operation, with errors: [NSError])
    {
        if let firstError = errors.first, (operation === downloadOperation || operation === parseOperation)
        {
            productAlert(firstError)
        }
    }
    
    fileprivate func productAlert(_ error: NSError)
    {
        guard !hasProducedAlert else { return }
        
        let alert = AlertOperation()
        
        switch error.domain
        {
        case OperationErrorDomain:
            // We failed because the network isn't reachable.
            let hostURL = error.userInfo[ReachabilityCondition.hostKey] as! URL
            
            alert.title = "Unable to Connect"
            alert.message = "Cannot connect to \(hostURL.host!). Make sure your device is connected to the internet and try again."
            
        case NSCocoaErrorDomain:
            // We failed because the JSON was malformed.
            alert.title = "Unable to Download"
            alert.message = "Cannot download earthquake data. Try again later."
            
        default:
            return
        }
        
        produceOperation(alert)
        hasProducedAlert = true
    }
}




