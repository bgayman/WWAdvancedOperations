# WWAdvancedOperations

Updated sample code from [WWDC 2015 session "Advanced NSOperations"](https://developer.apple.com/videos/play/wwdc2015/226/). Old code was written before the great re-naming and putting it through swift translator caused numerous errors. Also, the original sample code used `Operation` as its base class but because swift 3.0 naming changes renamed `NSOperation` as `Operation` this made for awkward name spacing. What the original project was called `Operation` is called `BaseOperation` in this project, `OperationQueue` is now `BaseOperationQueue`, etc. 

The sample code shows how to do a number of great things with operations, including how to make group and mutially exclusive operations, as well as add conditions to operations which can be useful in error and permissions handling.

While I updated some of the `CoreData` code, the notifications code does not use the new `UserNotifications` framework

Getting location wasn't working for me in the simulator, perhaps I have the wrong permissions key in `Info.plist`

![Screenshot](https://raw.githubusercontent.com/bgayman/WWAdvancedOperations/master/Screenshot.png)
