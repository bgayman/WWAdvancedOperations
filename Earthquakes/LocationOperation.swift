//
//  LocationOperation.swift
//  Earthquakes
//
//  Created by App Partner on 6/27/17.
//  Copyright © 2017 App Partner. All rights reserved.
//

import Foundation
import CoreLocation

class LocationOperation: BaseOperation, CLLocationManagerDelegate
{
    fileprivate let accuracy: CLLocationAccuracy
    fileprivate var manager: CLLocationManager?
    fileprivate let handler: (CLLocation) -> ()
    
    init(accuracy: CLLocationAccuracy, locationHandler: @escaping (CLLocation) -> ())
    {
        self.accuracy = accuracy
        self.handler = locationHandler
        super.init()
        add(LocationCondition(usage: .whenInUse))
        add(MutuallyExclusive<CLLocationManager>())
    }
    
    override func execute()
    {
        DispatchQueue.main.async
        {
            let manager = CLLocationManager()
            manager.desiredAccuracy = self.accuracy
            manager.delegate = self
            manager.startUpdatingLocation()
            self.manager = manager
        }
    }
    
    override func cancel()
    {
        DispatchQueue.main.async
        {
            self.stopLocationUpdates()
            super.cancel()
        }
    }
    
    fileprivate func stopLocationUpdates()
    {
        manager?.startUpdatingLocation()
        manager = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation])
    {
        guard let location = locations.last, location.horizontalAccuracy <= accuracy else { return }
        stopLocationUpdates()
        handler(location)
        finish()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
    {
        stopLocationUpdates()
        print(error.localizedDescription)
        finishWithError(error as NSError)
    }
}
