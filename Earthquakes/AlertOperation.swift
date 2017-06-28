//
//  AlertOperation.swift
//  Earthquakes
//
//  Created by App Partner on 6/23/17.
//  Copyright © 2017 App Partner. All rights reserved.
//

import UIKit

class AlertOperation: BaseOperation
{
    fileprivate let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
    fileprivate let presentationContext: UIViewController?
    
    var title: String?
    {
        get
        {
            return alertController.title
        }
        set
        {
            alertController.title = newValue
            name = newValue
        }
    }
    
    var message: String?
    {
        get
        {
            return alertController.message
        }
        set
        {
            alertController.message = newValue
        }
    }
    
    init(presentationContext: UIViewController? = nil)
    {
        self.presentationContext = presentationContext ?? UIApplication.shared.keyWindow?.rootViewController
        
        super.init()
        add(AlertPresentation())
        add(MutuallyExclusive<UIViewController>())
    }
    
    func addAction(_ title: String, style: UIAlertActionStyle = .default, handler: ((AlertOperation) -> ())? = nil)
    {
        let action = UIAlertAction(title: title, style: style)
        { [weak self] (_) in
            if let strongSelf = self
            {
                handler?(strongSelf)
            }
            self?.finish()
        }
        alertController.addAction(action)
    }
    
    override func execute()
    {
        guard let presentationContext = presentationContext else
        {
            finish()
            return
        }
        
        DispatchQueue.main.async
        {
            if self.alertController.actions.isEmpty
            {
                self.addAction("Ok")
            }
            presentationContext.present(self.alertController, animated: true)
        }
    }
}
