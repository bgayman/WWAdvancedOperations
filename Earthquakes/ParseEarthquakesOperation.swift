//
//  ParseEarthquakesOperation.swift
//  Earthquakes
//
//  Created by App Partner on 6/23/17.
//  Copyright © 2017 App Partner. All rights reserved.
//

import Foundation
import CoreData

private struct ParsedEarthquake
{
    let date: Date
    let identifier: String
    let name: String
    let link: String
    
    let depth: Double
    let latitude: Double
    let longitude: Double
    let magnitude: Double
    
    init?(feature: [String: Any])
    {
        guard let earthquakeID = feature["id"] as? String, !earthquakeID.isEmpty else { return nil }
        self.identifier = earthquakeID
        let properties = feature["properties"] as? [String: Any] ?? [:]
        
        self.name = properties["place"] as? String ?? ""
        self.link = properties["url"] as? String ?? ""
        self.magnitude = properties["mag"] as? Double ?? 0.0
        
        if let offset = properties["time"] as? Double
        {
            self.date = Date(timeIntervalSince1970: offset / 1000)
        }
        else
        {
            date = Date.distantFuture
        }
        
        let geometry = feature["geometry"] as? [String: Any] ?? [:]
        
        if let coordinates = geometry["coordinates"] as? [Double], coordinates.count == 3
        {
            longitude = coordinates[0]
            latitude = coordinates[1]
            depth = coordinates[2] * 1000
        }
        else
        {
            depth = 0
            latitude = 0
            longitude = 0
        }
    }
}

class ParseEarthquakesOperation: BaseOperation
{
    let cacheFile: URL
    let context: NSManagedObjectContext
    
    init(cacheFile: URL, context: NSManagedObjectContext)
    {
        let importContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        importContext.persistentStoreCoordinator = context.persistentStoreCoordinator
        
        importContext.mergePolicy = NSOverwriteMergePolicy
        
        self.cacheFile = cacheFile
        self.context = importContext
        
        super.init()
        name = "Parse Earthquakes"
    }
    
    override func execute()
    {
        guard let stream = InputStream(url: cacheFile) else
        {
            finish()
            return
        }
        
        stream.open()
        
        defer
        {
            stream.close()
        }
        
        do
        {
            let json = try JSONSerialization.jsonObject(with: stream, options: []) as? [String: Any]
            
            if let features = json?["features"] as? [[String: Any]]
            {
                parse(features)
            }
            else
            {
                finish()
            }
        }
        catch let jsonError as NSError
        {
            finishWithError(jsonError)
        }
    }
    
    fileprivate func parse(_ features: [[String: Any]])
    {
        let parsedEarthquakes = features.compactMap(ParsedEarthquake.init)
        let storedEarthquakes = (try? context.fetch(Earthquake.fetchRequest())) ?? []
        let earthquakeNameSet = Set(storedEarthquakes.map { ($0 as AnyObject).name ?? "" })
        context.perform
        {
            for newEarthquake in parsedEarthquakes
            {
                if !earthquakeNameSet.contains(newEarthquake.name)
                {
                    self.insert(newEarthquake)
                }
            }
            let error = self.saveContext()
            self.finishWithError(error)
        }
    }
    
    fileprivate func insert(_ parsed: ParsedEarthquake)
    {
        let earthquake = Earthquake(context: context)
        earthquake.identifier = parsed.identifier
        earthquake.timestamp = parsed.date
        earthquake.latitude = parsed.latitude
        earthquake.longitude = parsed.longitude
        earthquake.depth = parsed.depth
        earthquake.webLink = parsed.link
        earthquake.name = parsed.name
        earthquake.magnitude = parsed.magnitude
    }
    
    fileprivate func saveContext() -> NSError?
    {
        var error: NSError?
        guard context.hasChanges else { return nil }
        do
        {
            try context.save()
        }
        catch let saveError as NSError
        {
            error = saveError
        }
        return error
    }
}









