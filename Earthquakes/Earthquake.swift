//
//  Earthquake.swift
//  Earthquakes
//
//  Created by App Partner on 6/23/17.
//  Copyright © 2017 App Partner. All rights reserved.
//

import CoreData
import CoreLocation

@objc(Earthquake)
class Earthquake: NSManagedObject
{
    static let timestampFormatter: DateFormatter =
    {
        let timestampFormatter = DateFormatter()
        
        timestampFormatter.dateStyle = .medium
        timestampFormatter.timeStyle = .medium
        
        return timestampFormatter
    }()
    
    static let magnitudeFormatter: NumberFormatter =
    {
        let magnitudeFormatter = NumberFormatter()
        
        magnitudeFormatter.numberStyle = .decimal
        magnitudeFormatter.maximumFractionDigits = 1
        magnitudeFormatter.minimumFractionDigits = 1
        
        return magnitudeFormatter
    }()
    
    static let depthFormatter: LengthFormatter =
    {
        
        let depthFormatter = LengthFormatter()
        depthFormatter.isForPersonHeightUse = false
        
        return depthFormatter
    }()
    
    static let distanceFormatter: LengthFormatter =
    {
        let distanceFormatter = LengthFormatter()
        
        distanceFormatter.isForPersonHeightUse = false
        distanceFormatter.numberFormatter.maximumFractionDigits = 2
        
        return distanceFormatter
    }()
    
    var coordinate: CLLocationCoordinate2D
    {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var location: CLLocation
    {
        return CLLocation(coordinate: coordinate, altitude: -depth, horizontalAccuracy: kCLLocationAccuracyBest, verticalAccuracy: kCLLocationAccuracyBest, timestamp: (timestamp as Date?) ?? Date())
    }
}
