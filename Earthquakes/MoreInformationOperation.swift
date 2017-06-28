//
//  MoreInformationOperation.swift
//  Earthquakes
//
//  Created by App Partner on 6/23/17.
//  Copyright © 2017 App Partner. All rights reserved.
//

import Foundation
import SafariServices

class MoreInformationOperation: BaseOperation
{
    let url: URL
    
    init(url: URL)
    {
        self.url = url
        super.init()
        add(MutuallyExclusive<UIViewController>())
    }
    
    override func execute()
    {
        DispatchQueue.main.async
        {
            self.showSafariViewController()
        }
    }
    
    fileprivate func showSafariViewController()
    {
        if let context = UIApplication.shared.keyWindow?.rootViewController
        {
            let safari = SFSafariViewController(url: url)
            safari.delegate = self
            context.present(safari, animated: true)
        }
        else
        {
            finish()
        }
    }
}

extension MoreInformationOperation: SFSafariViewControllerDelegate
{
    func safariViewControllerDidFinish(_ controller: SFSafariViewController)
    {
        controller.dismiss(animated: true)
        {
            self.finish()
        }
    }
}
