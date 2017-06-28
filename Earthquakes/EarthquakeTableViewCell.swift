//
//  EarthquakeTableViewCell.swift
//  Earthquakes
//
//  Created by App Partner on 6/27/17.
//  Copyright © 2017 App Partner. All rights reserved.
//

import UIKit

final class EarthquakeTableViewCell: UITableViewCell
{
    
    @IBOutlet weak var magnitudeLabel: UILabel!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var magnitudeImage: UIImageView!
    @IBOutlet weak var timestampLabel: UILabel!
    
    var earthquake: Earthquake?
    {
        didSet
        {
            guard let earthquake = self.earthquake else { return }
            timestampLabel.text = Earthquake.timestampFormatter.string(from: (earthquake.timestamp as Date?) ?? Date())
            magnitudeLabel.text = Earthquake.magnitudeFormatter.string(from: NSNumber(value: earthquake.magnitude))
            locationLabel.text = earthquake.name
            let imageName: String
            switch earthquake.magnitude
            {
            case 0 ..< 2:
                imageName = ""
            case 2 ..< 3:
                imageName = "2.0"
            case 3 ..< 4:
                imageName = "3.0"
            case 4 ..< 5:
                imageName = "4.0"
            default:
                imageName = "5.0"
            }
            magnitudeImage.image = UIImage(named: imageName)
        }
    }
}
