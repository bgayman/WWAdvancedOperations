//
//  LoadModelOperation.swift
//  Earthquakes
//
//  Created by App Partner on 6/23/17.
//  Copyright © 2017 App Partner. All rights reserved.
//

import CoreData

class LoadModelOperation: BaseOperation
{
    let loadHandler: (NSPersistentContainer) -> ()
    
    init(loadHandler: @escaping (NSPersistentContainer) -> ())
    {
        self.loadHandler = loadHandler
        super.init()
        add(MutuallyExclusive<LoadModelOperation>())
    }
    
    override func execute()
    {
        let container = NSPersistentContainer(name: "Earthquake")
        container.loadPersistentStores
        { [unowned self] (storeDescription, error) in
            container.viewContext.automaticallyMergesChangesFromParent = true
            try? container.viewContext.setQueryGenerationFrom(.current)
            if let error = error as NSError?
            {
                self.finishWithError(error)
            }
            else
            {
                self.loadHandler(container)
                self.finish()
            }
        }
    }
    
    override func finished(_ errors: [NSError])
    {
        guard let firstError = errors.first, userInitiated else { return }
        
        let alert = AlertOperation()
        alert.title = "Unable to Load Database"
        alert.message = "An error occurred while loading the database. \(firstError.localizedDescription). Please try again later."
        
        alert.addAction("Retry Later", style: .cancel)
        
        let handler = loadHandler
        
        alert.addAction("Retry Now")
        { (alertOperation) in
            let retryOperation = LoadModelOperation(loadHandler: handler)
            retryOperation.userInitiated = true
            alertOperation.produceOperation(retryOperation)
        }
        
        produceOperation(alert)
    }
}
