//
//  SplitViewController.swift
//  Earthquakes
//
//  Created by App Partner on 6/27/17.
//  Copyright © 2017 App Partner. All rights reserved.
//

import UIKit

final class SplitViewController: UISplitViewController
{
    override func awakeFromNib()
    {
        super.awakeFromNib()
        preferredDisplayMode = .allVisible
        delegate = self
    }
}

extension SplitViewController: UISplitViewControllerDelegate
{
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool
    {
        guard let navigation = secondaryViewController as? UINavigationController else { return false }
        guard let detail = navigation.viewControllers.first as? EarthquakeDetailTableViewController else { return false }
        
        return detail.earthquake == nil
    }
}
