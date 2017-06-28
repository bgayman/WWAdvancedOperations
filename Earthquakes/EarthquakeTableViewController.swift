//
//  EarthquakeTableViewController.swift
//  Earthquakes
//
//  Created by App Partner on 6/23/17.
//  Copyright © 2017 App Partner. All rights reserved.
//

import UIKit
import CoreData

class EarthquakeTableViewController: UITableViewController
{

    var fetchResultsController: NSFetchedResultsController<Earthquake>?
    
    let operationQueue = BaseOperationQueue()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.refreshControl = UIRefreshControl()
        self.refreshControl?.addTarget(self, action: #selector(self.startRefreshing(_:)), for: .valueChanged)
        tableView.estimatedRowHeight = 68
        tableView.rowHeight = UITableViewAutomaticDimension
        
        
        let operation = LoadModelOperation
        { (container) in
            DispatchQueue.main.async
            {
                let request: NSFetchRequest<Earthquake> = Earthquake.fetchRequest()
                
                request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
                request.fetchLimit = 100
                
                let controller = NSFetchedResultsController(fetchRequest: request, managedObjectContext: container.viewContext, sectionNameKeyPath: nil, cacheName: nil)
                self.fetchResultsController = controller
                self.updateUI()
                self.getEarthquakes(false)
            }
        }
        operationQueue.addOperation(operation)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let navigationVC = segue.destination as? UINavigationController,
              let detailVC = navigationVC.viewControllers.first as? EarthquakeDetailTableViewController
              else { return }
        detailVC.queue = operationQueue
        
        if let indexPath = tableView.indexPathForSelectedRow
        {
            detailVC.earthquake = fetchResultsController?.object(at: indexPath)
        }
    }
    
    fileprivate func updateUI()
    {
        do
        {
            try fetchResultsController?.performFetch()
        }
        catch
        {
            print("Error in the fetched results controller: \(error).")
        }
        tableView.reloadData()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return fetchResultsController?.sections?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        let section = fetchResultsController?.sections?[section]
        return section?.numberOfObjects ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath) as! EarthquakeTableViewCell

        cell.earthquake = fetchResultsController?.object(at: indexPath)
        
        return cell
    }

    @objc func startRefreshing(_ sender: UIRefreshControl)
    {
        getEarthquakes()
    }
    
    fileprivate func getEarthquakes(_ userInitiated: Bool = true)
    {
        if let context = fetchResultsController?.managedObjectContext
        {
            let getEarthquakesOperation = GetEarthquakesOperation(context: context)
            {
                DispatchQueue.main.async
                {
                    self.refreshControl?.endRefreshing()
                    self.updateUI()
                }
            }
            getEarthquakesOperation.userInitiated = userInitiated
            operationQueue.addOperation(getEarthquakesOperation)
        }
        else
        {
            let when = DispatchTime.now() + Double(Int64(0.3 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
            DispatchQueue.main.asyncAfter(deadline: when)
            {
                self.refreshControl?.endRefreshing()
            }
        }
    }
}
