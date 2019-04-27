//
//  EarthquakeDetailTableViewController.swift
//  Earthquakes
//
//  Created by App Partner on 6/27/17.
//  Copyright © 2017 App Partner. All rights reserved.
//

import UIKit
import MapKit

final class EarthquakeDetailTableViewController: UITableViewController
{
    var queue: BaseOperationQueue?
    var earthquake: Earthquake?
    var locationRequest: LocationOperation?
    
    @IBOutlet weak var map: MKMapView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var magnitudeLabel: UILabel!
    @IBOutlet weak var depthLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        guard let earthquake = earthquake else
        {
            nameLabel.text = nil
            magnitudeLabel.text = nil
            depthLabel.text = nil
            timeLabel.text = nil
            distanceLabel.text = nil
            return
        }
        
        let span = MKCoordinateSpan(latitudeDelta: 15, longitudeDelta: 15)
        map.region = MKCoordinateRegion(center: earthquake.coordinate, span: span)
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = earthquake.coordinate
        map.addAnnotation(annotation)
        
        nameLabel.text = earthquake.name
        magnitudeLabel.text = Earthquake.magnitudeFormatter.string(from: NSNumber(value: earthquake.magnitude))
        depthLabel.text = Earthquake.depthFormatter.string(fromMeters: earthquake.depth)
        timeLabel.text = Earthquake.timestampFormatter.string(from: earthquake.timestamp as Date? ?? Date())
        
        let locationOperation = LocationOperation(accuracy: kCLLocationAccuracyKilometer)
        { (location) in
            if let earthquakeLocation = self.earthquake?.location
            {
                let distance = location.distance(from: earthquakeLocation)
                self.distanceLabel.text = Earthquake.distanceFormatter.string(fromMeters: distance)
            }
            self.locationRequest = nil
        }
        
        let locationErrorObserver = BlockObserver
        { [weak self] (operation, errors) in
            if let error = errors.first
            {
                let alert = AlertOperation(presentationContext: self)
                alert.title = "🙈"
                alert.message = error.localizedDescription
                self?.queue?.addOperation(alert)
            }
        }
        
        locationOperation.add(locationErrorObserver)
        
        queue?.addOperation(locationOperation)
        locationRequest = locationOperation
        map.delegate = self
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        locationRequest?.cancel()
    }
    
    @IBAction func shareEarthquake(_ sender: UIBarButtonItem)
    {
        guard let earthquake = earthquake,
              let url = URL(string: earthquake.webLink ?? " ") else { return }
        
        let location = earthquake.location
        
        let items = [url, location] as [Any]
        
        let shareOperation = BaseBlockOperation
        { (continuation) in
            DispatchQueue.main.async
            {
                let shareSheet = UIActivityViewController(activityItems: items, applicationActivities: nil)
                shareSheet.popoverPresentationController?.barButtonItem = sender
                
                shareSheet.completionWithItemsHandler =
                { (_, _, _, _) in
                    continuation()
                }
                
                self.present(shareSheet, animated: true)
            }
        }
        
        shareOperation.add(MutuallyExclusive<UIViewController>())
        queue?.addOperation(shareOperation)
    
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        if indexPath.section == 1 && indexPath.row == 0
        {
            if let link = earthquake?.webLink, let url = URL(string: link)
            {
                let moreInformation = MoreInformationOperation(url: url)
                queue?.addOperation(moreInformation)
            }
            else
            {
                let alert = AlertOperation(presentationContext: self)
                alert.title = "No Information"
                alert.message = "No other information is available for this earthquake"
                queue?.addOperation(alert)
            }
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension EarthquakeDetailTableViewController: MKMapViewDelegate
{
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView?
    {
        guard let earthquake = earthquake else { return nil }
        
        var view = mapView.dequeueReusableAnnotationView(withIdentifier: "pin") as? MKPinAnnotationView
        view = view ?? MKPinAnnotationView(annotation: annotation, reuseIdentifier: "pin")
        guard let pin = view else { return nil }
        
        switch earthquake.magnitude
        {
        case 0 ..< 3:
            pin.pinTintColor = UIColor.gray
        case 3 ..< 4:
            pin.pinTintColor = UIColor.blue
        case 4 ..< 5:
            pin.pinTintColor = UIColor.orange
        default:
            pin.pinTintColor = UIColor.red
        }
        
        pin.isEnabled = false
        pin.animatesDrop = true
        return pin
    }
}





