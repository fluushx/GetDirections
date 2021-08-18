//
//  ViewController.swift
//  GetDirectionsDemo
//
//  Created by Alex Nagy on 12/02/2020.
//  Copyright © 2020 Alex Nagy. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import Layoutless
import AVFoundation

class ViewController: UIViewController {
    
    var steps: [MKRoute.Step] = []
    var stepsCounter = 0
    var route : MKRoute?
    var showMapRoute = false
    var navigationStarted = false
    var locationDistante : Double = 500
    
    var speechSynthesizer = AVSpeechSynthesizer()
    
    lazy var locationManager:CLLocationManager = {
        let locationManager = CLLocationManager()
        //check service is enable
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            //authorization
            handleAuthorizationStatus(locationManager: locationManager,
                                      status: CLLocationManager.authorizationStatus())
 
        }
        else {
            print("Location not are enable")
        }
        
        return locationManager
    }()
    
    lazy var directionLabel: UILabel = {
        let label = UILabel()
        label.text = "Where do you want to go?"
        label.font = .boldSystemFont(ofSize: 16)
        label.textAlignment = .center
        label.numberOfLines = 0
        
        return label
    }()
    
    lazy var textField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Enter your destination"
        tf.borderStyle = .roundedRect
        tf.layer.cornerRadius = 10
        tf.backgroundColor = .systemGray5
        return tf
    }()
    
    lazy var getDirectionButton: UIButton = {
        let button = UIButton()
        button.setTitle("Get Direction", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
        button.backgroundColor = .blue
        button.layer.cornerRadius = 10
        button.addTarget(self, action: #selector(getDirectionButtonTapped), for: .touchUpInside)
        
        return button
    }()
    
    lazy var uiView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        return view
    }()
    
    lazy var startStopButton: UIButton = {
        let button = UIButton()
        button.setTitle("Start Navigation", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
        button.addTarget(self, action: #selector(startStopButtonTapped), for: .touchUpInside)
        button.backgroundColor = .blue
        button.layer.cornerRadius = 10
        return button
    }()
    
    
    lazy var mapView: MKMapView = {
        let mapView = MKMapView()
        mapView.delegate = self
        mapView.showsUserLocation = true
        return mapView
    }()
    
    @objc fileprivate func getDirectionButtonTapped() {
        guard let text = textField.text else {
            return
        }
        showMapRoute = true
        textField.endEditing(true)
        
        //geoCoder
        let geoCoder = CLGeocoder()
        geoCoder.geocodeAddressString(text) { (placemarks, error) in
            if let error = error {
                print(error.localizedDescription)
                return
            }
            guard let placemarks = placemarks,
                  let placemark = placemarks.first,
                  let location = placemark.location
                  else {
                return
            }
            let destionationCoordinate = location.coordinate
            self.mapRoute(destinationCoordinate: destionationCoordinate)
            
        }
    }
    
    @objc fileprivate func startStopButtonTapped() {
        if !navigationStarted {
            showMapRoute = true
            if let location = locationManager.location {
                let center = location.coordinate
                centerViewToUserLocation(center: center)
            }
        }
        else {
            if let route  = route{
                self.mapView.setVisibleMapRect(route.polyline.boundingMapRect,
                                               edgePadding: UIEdgeInsets(top: 16,
                                                                         left: 16,
                                                                         bottom: 16,
                                                                         right: 16),
                                               animated: true)
                self.steps.removeAll()
                self.stepsCounter = 0
            }
        }
        
        navigationStarted.toggle()
        startStopButton.setTitle(navigationStarted ? "Stop Navigation" : "Start Navigation", for: .normal)
    
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager.startUpdatingLocation()
         
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        mapView.frame =  view.bounds
        setUpView()
        
        
    }
    
    fileprivate func setUpView(){
        
        view.backgroundColor = .systemBackground
        view.addSubview(mapView)
        view.addSubview(uiView)
        uiView.addSubview(directionLabel)
        uiView.addSubview(textField)
        uiView.addSubview(getDirectionButton)
        uiView.addSubview(startStopButton)
        
        uiView.frame = CGRect(x: uiView.frame.size.width , y: uiView.frame.size.height, width: view.frame.size.width , height: view.frame.size.height-580)
        let xPosition : CGFloat = uiView.frame.origin.x + directionLabel.frame.size.width + 10
        directionLabel.frame = CGRect(x: xPosition, y: 40, width: directionLabel.frame.size.width + uiView.frame.size.width - 20, height: 70)
        textField.frame = CGRect(x: textField.frame.size.height + 10, y: 120, width: 200, height: 50)
        getDirectionButton.frame = CGRect (x: textField.frame.size.width + 20 , y: 120, width: 145, height: 50)
        startStopButton.frame = CGRect (x: 10 , y: textField.frame.size.height + 130 , width: 355, height: 45)
    }
    
     
    
    fileprivate func centerViewToUserLocation(center: CLLocationCoordinate2D) {
        let region = MKCoordinateRegion(center: center,
                                        latitudinalMeters: locationDistante,
                                        longitudinalMeters: locationDistante)
        mapView.setRegion(region, animated: true)
    }
    
    fileprivate func handleAuthorizationStatus(locationManager: CLLocationManager, status: CLAuthorizationStatus) {
        switch status {
        
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            break
        case .restricted:
            break
        case .denied:
            break
        case .authorizedAlways:
            break
        case .authorizedWhenInUse:
            //toDo Next
            if let center = locationManager.location?.coordinate{
                centerViewToUserLocation(center: center)
            }
            break
        @unknown default:
            fatalError()
            break
        }
    }
    fileprivate func mapRoute(destinationCoordinate: CLLocationCoordinate2D) {
        guard let sourceCoordinate = locationManager.location?.coordinate else {
            return
        }
        let sourcePlacemark = MKPlacemark(coordinate: sourceCoordinate)
        let destinationPlaceMark = MKPlacemark(coordinate: destinationCoordinate)
        
        let sourceItem = MKMapItem(placemark: sourcePlacemark)
        let destinationItem = MKMapItem(placemark: destinationPlaceMark)
        
        let routeRequest = MKDirections.Request()
        routeRequest.source = sourceItem
        routeRequest.destination = destinationItem
        routeRequest.transportType = .automobile
        
        let directions = MKDirections(request: routeRequest)
        directions.calculate { response, error in
            if let error = error {
                print(error.localizedDescription)
                return
            }
            guard let response =  response, let route = response.routes.first else {
                return
            }
            self.route = route
            self.mapView.addOverlay(route.polyline)
            self.mapView.setVisibleMapRect(route.polyline.boundingMapRect,
                                           edgePadding: UIEdgeInsets(top: 16,
                                                                     left: 16,
                                                                     bottom: 16,
                                                                     right: 16),
                                           animated: true)
            self.getRouteSteps(route: route)
        }
    }
    
    fileprivate func getRouteSteps(route: MKRoute) {
        for monitoredRegion in locationManager.monitoredRegions{
            locationManager.stopMonitoring(for: monitoredRegion)
        }
        let steps = route.steps
        self.steps = steps
        
        for i in 0..<steps.count{
            let step =  steps[i]
            print(step.instructions)
            print(step.distance)
            let region = CLCircularRegion(center: step.polyline.coordinate,
                                          radius: 20,
                                          identifier: "\(i)")
            locationManager.startMonitoring(for: region)
        }
        stepsCounter += 1
        let initialMessage = "In \(steps[stepsCounter].distance) meters instruction1, then in \(steps[stepsCounter].instructions) meters, then in \(steps[stepsCounter + 1].distance) meters,  \(steps[stepsCounter + 1].instructions)"
        directionLabel.text = initialMessage
        print(initialMessage)
        let speechUtterance = AVSpeechUtterance(string: initialMessage)
        speechSynthesizer.speak(speechUtterance)
        
    }

}


extension ViewController: CLLocationManagerDelegate{
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if !showMapRoute {
            if let location = locations.last{
                let center = location.coordinate
                centerViewToUserLocation(center: center)
            }
        }
        else {
            
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
         handleAuthorizationStatus(locationManager: locationManager,
                                   status: status)
    }
     func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        stepsCounter += 1
        if stepsCounter < steps.count {
            let message = "In \(steps[stepsCounter].distance) meters, then in \(steps[stepsCounter].instructions)"
            directionLabel.text = message
            let speechUtterance = AVSpeechUtterance(string: message)
            speechSynthesizer.speak(speechUtterance)
        }
        else {
            let messege = "you have arrive at yout destination"
            directionLabel.text = messege
            stepsCounter = 0
            navigationStarted = false
            for monitoredRegion in locationManager.monitoredRegions{
                locationManager.stopMonitoring(for: monitoredRegion)
            }
        }
    }
}

extension ViewController: MKMapViewDelegate{
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.strokeColor = .systemBlue
        return renderer
    }
}
