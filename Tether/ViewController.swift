//
//  ViewController.swift
//  Tether
//  Locate your car with the help of augmented reality
//  Created by ChrisLee on 1/29/19.
//  Copyright © 2019 ChrisLee. All rights reserved.
//

import UIKit
import ARKit
import CoreLocation
import Firebase
import GeoFire
import FirebaseDatabase
import SwiftMessages
/**
 *  As of right now there is a margin of error around ~5-10 meters where the
 *  marker should be placed. This is because of the way the GPS is calculated
 *  when using CLLocationManager. The GPS results can be inconsistent.
 *  Here is where GeoFire has the potential to fix this issue. Currently
 *  we are not implementing GeoFire's features. If GeoFire is not able to produce
 *  accurate GPS coordinates and distance then it should be removed and Tether
 *  should only use FireBase.
 *
 *  Keep in mind the coordinate frame is static upon running the app. The coordinate
 *  frame does NOT move with the user and will always be interpreted relative to
 *  the reference frame (the established frame at the start of the app). However, once the app is paused or brought to the background the frame of reference resets upon
     bringing the app back to the foreground. It is necessary to save the frame of reference that was established at the start of the app if possible or recalibrate
         the worldOrigin to match the coordinate plane at the start when the car location
         was saved.
 *  UPDATE instead of recalibration just need to calculate translation vector when the app
 *  is brought back to the foreground
 *  Since Tether is an AR app which involves the use of graphics the GPU usage for the phone is around 50% causing high energy impact. So leaving the app running in the background may drain the user's battery. A work around may need to be implmeneted.
 *
 *  TODO: TEST ELEVATION, and recalibrate or reset worldOrigin (starting coordinate plane)
 */
class ViewController: UIViewController, CLLocationManagerDelegate {
    @IBOutlet var button: UIButton!
    //using hard coded coordinate until able to pull from database
    //testCoordinate will act as the CAR LOCATION
    /*var testCoordinate = CLLocation(latitude: 33.79230995341299, longitude: -84.32320634781253)*/
    var testCoordinate = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 33.79847873417613, longitude: -84.30954309336566), altitude: 283.052764892578, horizontalAccuracy: kCLLocationAccuracyBest, verticalAccuracy: kCLLocationAccuracyBest, timestamp: Date())
    //database reference for firebase
    var geofireRef : DatabaseReference!
    //distance between the car location and the user when they return the car
    var distance = 0.0
    var userCoords : CLLocation!
    /**
         The latittude and longitude of the Tether user
         @param latitude the latitude of the user
         @param longitude the longitude of the user
         @param geoFire the database reference for the specific user
    */
    struct TetherUser {
        var latitude : Double
        var longitude : Double
        var geoFire : GeoFire!

        init(lat : Double, long : Double) {
            self.latitude = lat
            self.longitude = long
        }
        
        func printGPS() {
            print("USERS LAT: \(self.latitude),  USERS LONG: \(self.longitude)")
        }
    }
    //using ARKit's scene view to place marker into real world
    var scene_view : ARSCNView!
    //var button : UIButton!
    let location_manager = CLLocationManager()
    override func viewDidLoad() {
        super.viewDidLoad()
        geofireRef = Database.database().reference()
        location_manager.requestWhenInUseAuthorization()
        //location_manager.requestAlwaysAuthorization()
        print("request should be made")
        if CLLocationManager.locationServicesEnabled() {
            print("getting location");
            location_manager.delegate = self
            //need to test kCLLocationAccuracyBestForNavigation may be able
            //get more accurate & consistent GPS coords
            //however, the drawback is high power consumption per docs:
            //"use this level of accuracy only when the device is plugged in"
            //
            //UPDATE: tested different desiredAccuracies. kCLLocationAccuracyBest provides
            //the best results and has the same high power impact as the others
            //
            location_manager.desiredAccuracy = kCLLocationAccuracyBest
            location_manager.startUpdatingLocation()
        }
        print(getCarLocation)
        scene_view = ARSCNView()
        scene_view.frame = view.frame
        view.addSubview(scene_view)
        let config = ARWorldTrackingConfiguration()
        scene_view.session.run(config)
        
        //debug: show feature points, FPS, and coordinate frame
        //scene_view.showsStatistics = true
        scene_view.debugOptions = ARSCNDebugOptions.showWorldOrigin
        //scene_view.debugOptions = ARSCNDebugOptions.showFeaturePoints
        
        // the whole screen will act as a button i.e. tap anywhere on the screen
        button = UIButton()
        button.frame = view.frame
        view.addSubview(button)

        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(normalTap(_:)))
        tapGesture.numberOfTapsRequired = 2
        button.addGestureRecognizer(tapGesture)
        
        let longGesture = UILongPressGestureRecognizer(target: self, action: #selector(longTap(_:)))
        button.addGestureRecognizer(longGesture)
    }
    
    @objc func normalTap(_ sender: UIGestureRecognizer){
        print("Normal tap")
        //queryCarLocation()
        lookForCarMessage()
        renderMarker()
    }
    
    @objc func longTap(_ sender: UIGestureRecognizer){
        print("Long tap")
        if sender.state == .ended {
            print("UIGestureRecognizerStateEnded")
            carSavedMessage()
            
        }
        else if sender.state == .began {
            print("UIGestureRecognizerStateBegan.")
            location_manager.startUpdatingLocation()
        }
    }
    
    func lookForCarMessage() {
        let alert = MessageView.viewFromNib(layout: .messageView)
        alert.button?.isHidden = true
        alert.configureTheme(.info)
        alert.configureContent(title: "CAR AREA MARKED!", body: "Look for the green tic tac!")
        SwiftMessages.show(view: alert)
    }
    
    
    func carSavedMessage() {
        let alert = MessageView.viewFromNib(layout: .messageView)
        alert.button?.isHidden = true
        alert.configureTheme(.info)
        alert.configureContent(title: "Success!", body: "Your car location has been saved!")
        SwiftMessages.show(view: alert)

        print("Query results::")
        print(getCarLocation())

    }
    
    /**
         Retrieves phone/current location of user
         Store and query from the database
    */
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            //print(location.coordinate)
            var tether_user = TetherUser.init(lat:location.coordinate.latitude, long: location.coordinate.longitude)
            //let geoFire makes a reference to the db so you can use geoFire at any point
            tether_user.geoFire = GeoFire(firebaseRef: geofireRef)
            //stores the latitude and longitude under the currentLocation node
            tether_user.geoFire.setLocation(CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude), forKey: "carLocation"){

                //testing to see if location data was saved.

                (error) in
                if (error != nil) {
                    print("An error occured: \(String(describing: error))" )
                } else {
                    print("Saved car location successfully!")
                }
                print("USER distance from car:")
                
                self.userCoords = CLLocation(coordinate: CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude), altitude: location.altitude, horizontalAccuracy: kCLLocationAccuracyBest, verticalAccuracy: kCLLocationAccuracyBest, timestamp: Date())
                self.distance = self.userCoords.distance(from: self.testCoordinate)
                print(self.distance)
            }

            //gets the value stored in currentLocation from database
            tether_user.geoFire.getLocationForKey("carLocation", withCallback: {
                (location, err) in if(err != nil){
                    print("Error getting current location \(err.debugDescription)")
                } else {
                    print("TetherDatabase does not contain a location for \"carLocation\"")
                }
                
                print("TEST COORDINATE: \(self.testCoordinate)")
            })
            print("ELEVATION: \(location.altitude)")
            geoFire.setLocation(CLLocation(location.altitude), forKey: "Altitude")
            print("Current LOCATION: \(location.coordinate)")
            self.location_manager.stopUpdatingLocation()

        }
    }

  

    /** get the carLocation from the db */
    func getCarLocation(){
        let geoFire = GeoFire(firebaseRef: geofireRef)
        geoFire.getLocationForKey("carLocation") { (location, error) in
            if (error != nil) {
                print("An error occurred getting the location for \"carLocation\": \(error?.localizedDescription)")
            } else if (location != nil) {
                print("Location for \"carLocation\" is [\(location?.coordinate.latitude), \(location?.coordinate.longitude)]")
            } else {
                print("GeoFire does not contain a location for \"carLocation\"")
            }
        }
        
    }
>>>>>>> Stashed changes
    
    /**
         callback for location manager
    */
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if (status == CLAuthorizationStatus.denied) {
            showLocationDisabledPopUp()
        }
    }
    /**
         if location access is disabled then alert user
    */
    func showLocationDisabledPopUp() {
        let alert = UIAlertController(title: "Location Access Disabled", message: "Need location to place marker on car", preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        let openAction = UIAlertAction(title: "Open Settings", style: .default) { (action) in
            if let url = URL(string: UIApplicationOpenSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        alert.addAction(openAction)
        self.present(alert, animated: true, completion: nil)
    }
    /**
         calculates and returns the bearing between the user's GPS coordinate and
         the car's GPS coordinate
         converts degrees to radians
    */
    func getBearing(fromUSER: CLLocation, toCAR: CLLocation) -> Double {
        let userLat = (fromUSER.coordinate.latitude * .pi) / 180
        let userLong = (fromUSER.coordinate.longitude * .pi) / 180
        let carLat = (toCAR.coordinate.latitude * .pi) / 180
        let carLong = (toCAR.coordinate.longitude * .pi) / 180
        
        let bearing = atan2(sin(carLong - userLong) * cos(carLat), cos(userLat) * sin(carLat) - sin(userLat) * cos(carLat) * cos(userLat) * cos(carLong - userLong))
        print("BEARING ANGLE: \(bearing)" )
        return bearing
    }
    /**
         returns the translation vector used to place marker into 3D space
         spanning across the x-axis (left or right) and the y-axis (elevation/altitude)
    */
    func getTransVector(user: CLLocation, car: CLLocation) -> SCNVector3 {
        var bearing = getBearing(fromUSER: user, toCAR: car)
        //if negative radians convert to positive
        if(bearing < 0.0) {
            bearing += 2 * .pi;
        }
        let y = car.altitude - user.altitude
        print("y-axis(altitude): \(y)")
        print("getTransVector bearing input: \(bearing)")
        switch bearing {
        case 0.0...1.5707 :
           let x = sin(bearing) * self.distance
           let z = cos(bearing) * self.distance
           let translation = SCNVector3(x,y,-z)
           print("QUADRANT I")
           return translation
        case 1.5707...3.14159 :
            bearing = bearing - 1.5707
            let x = cos(bearing) * self.distance
            let z = sin(bearing) * self.distance
            let translation = SCNVector3(x,y,z)
            print("QUADRANT II")
            return translation
        case 3.14159...4.7124 :
            bearing = bearing - 3.14159
            let x = sin(bearing) * self.distance
            let z = cos(bearing) * self.distance
            let translation = SCNVector3(-x,y,z)
            print("QUADRANT III")
            return translation
        case 4.7124...6.2832 :
            bearing = bearing - 4.7124
            let x = cos(bearing) * self.distance
            let z = sin(bearing) * self.distance
            let translation = SCNVector3(-x,y,-z)
            print("QUADRANT IV")
            return translation
        default:
            print("DEFAULT SWITCH")
            return SCNVector3(0,0,0)
        }
    }
    /**
         Renders the 3D marker onto the user's car
    */
    @objc func renderMarker() {
        if let camera = scene_view.session.currentFrame?.camera {
            let cameraObject = MDLTransform(matrix: camera.transform)
            //var position = cameraObject.translation
            //let position = SCNVector3(0, 0, -self.distance) replacing this with function renderMarker()
            //let box = SCNBox(width: 0.1, height: 0.1, length: 0.1, chamferRadius: 0.0)
            let capsule = SCNCapsule(capRadius: 0.1, height: 0.3);
            capsule.firstMaterial?.diffuse.contents = UIColor.green
            let boxNode = SCNNode(geometry: capsule)
            //boxNode.position = SCNVector3(position)
            boxNode.position = getTransVector(user: userCoords, car: testCoordinate)
            scene_view.scene.rootNode.addChildNode(boxNode)
        }
    }
    
     override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

