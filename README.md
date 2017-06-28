# WWAdvancedOperations

Updated sample code from [WWDC 2015 session "Advanced NSOperations"](https://developer.apple.com/videos/play/wwdc2015/226/). Old code was written before the great re-naming and putting it through swift translator caused numerous errors. 

The sample code shows how to do a number of great things with operations, including how to make group and mutially exclusive operations, as well as add conditions to operations which can be useful in error and permissions handling.

While I updated some of the `CoreData` code. The notifications code does not use the new `UserNotifications` framework

Getting location wasn't working for me in the simulator, perhaps I have the wrong permissions key in `Info.plist`

![Screenshot](https://raw.githubusercontent.com/bgayman/WWAdvancedOperations/master/Screenshot.png)
