//
//  MapViewController.swift
//  RVNav
//
//  Copyright © 2020 RVNav. All rights reserved.
//

import UIKit
import SwiftKeychainWrapper
import FirebaseAnalytics
import ArcGIS

class MapViewController: UIViewController, AGSGeoViewTouchDelegate {
    
    // MARK: - Properties
    private var modelController = ModelController(userController: UserController())
    private var directionsController: DirectionsControllerProtocol =
        DirectionsController(mapAPIController: AGSMapAPIController(avoidanceController:
            AvoidanceController(avoidanceProvider:
                LambdaDSAvoidanceProvider())))
    private let graphicsOverlay = AGSGraphicsOverlay()
    private var routeLineColor: UIColor = .blue {
        didSet {
            DispatchQueue.main.async {
                self.drawRouteLine()
            }
        }
    }
    private let routeTask = AGSRouteTask(url: URL(string: "https://route.arcgis.com/arcgis/rest/services/World/Route/NAServer/Route_World")!)
    
    private var mapType: AGSBasemapType = .navigationVector {
        didSet{
            var map: AGSMap
            routeLineColor = .blue
            switch self.mapType {
            case .navigationVector:
                map = AGSMap(basemap: AGSBasemap.navigationVector())
            case .imageryWithLabelsVector:
                map = AGSMap(basemap: AGSBasemap.imageryWithLabelsVector())
            case .terrainWithLabelsVector:
                map = AGSMap(basemap: AGSBasemap.terrainWithLabelsVector())
            case .streetsNightVector:
                routeLineColor = .red
                map = AGSMap(basemap: AGSBasemap.streetsNightVector())
            default:
                return
            }
            DispatchQueue.main.async {
                self.mapView.map = map
                guard let route = self.directionsController.mapAPIController.selectedRoute,
                    let routeGeometry = route.routeGeometry else { return }
                    self.mapView.setViewpointGeometry(routeGeometry, padding: 100, completion: nil)
            }
        }
    }
    
    // MARK: - IBOutlets
    @IBOutlet private weak var mapView: AGSMapView!
    @IBOutlet weak var getRouteTestButton: UIButton!
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        Analytics.logEvent("app_opened", parameters: nil)
        //Listen out for a notification that a route was selected and triggers mapRoute
        NotificationCenter.default.addObserver(self, selector: #selector(mapRoute(notification:)), name: .routeNeedsMapped, object: nil)
        //Initial map/mapView setup
        setupMap()
    }
    
    deinit {
        mapView.locationDisplay.stop()
        mapView = nil
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        //Check if this is the first launch and send to LaunchPage if so
        if UserDefaults.isFirstLaunch() {
            performSegue(withIdentifier: "LandingPageSegue", sender: self)
        } else if
            //check if we have a stored API token (logged in)
            KeychainWrapper.standard.string(forKey: "accessToken") == nil && !UserDefaults.isFirstLaunch() {
            performSegue(withIdentifier: "SignInSegue", sender: self)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "SignInSegue" {
            let destinationVC = segue.destination as! SignInViewController
            destinationVC.userController = modelController.userController
        }
        if segue.identifier == "LandingPageSegue" {
            let destinationVC = segue.destination as! LandingPageViewController
            destinationVC.userController = modelController.userController
        }
        if segue.identifier == "HamburgerMenu" {
            let destinationVC = segue.destination as! CustomSideMenuNavigationController
            destinationVC.modelController = modelController
            destinationVC.mapAPIController = directionsController.mapAPIController
            destinationVC.menuDelegate = self
        }
    }
    
    // MARK: - IBActions
    @IBAction func logOutButtonTapped(_ sender: Any) {
        modelController.userController.logout {
            DispatchQueue.main.async {
                self.graphicsOverlay.graphics.removeAllObjects()
                self.performSegue(withIdentifier: "SignInSegue", sender: self)
            }
        }
    }
    
    @IBAction func unwindToMapView(segue:UIStoryboardSegue) { }
    
    @IBAction private func getRouteTestButtonTapped(_ sender: UIButton) {
        directionsController.mapAPIController.testRoute()
    }
    
    @objc public func mapRoute(notification: NSNotification) {
        //Check if we have a route selected by user
        guard let route = directionsController.mapAPIController.selectedRoute else
        { //if not show map at current location
            guard let location = mapView.locationDisplay.location,
                let lat = location.position?.y,
                let lon = location.position?.x
                else { return }
            DispatchQueue.main.async {
                self.mapView.map = AGSMap(basemapType: self.mapType, latitude: lat, longitude: lon, levelOfDetail: 18)
            }
            return
                
        }
        //If we DO have a route display it
        DispatchQueue.main.async {
            if let routeGeometry = route.routeGeometry {
                //Draw the route in an overlay and add it, clearing any previous
                self.drawRouteLine()
                
                //Mark start and stop points
                guard let start = route.stops.first?.geometry,
                    let end = route.stops.last?.geometry else { return }
                self.addMapMarker(location: start, style: .diamond, fillColor: .green, outlineColor: .black)
                self.addMapMarker(location: end, style: .X, fillColor: .red, outlineColor: .red)
                //Set the map scale with padding
            self.mapView.setViewpointGeometry(routeGeometry, padding: 100, completion: nil)
            }
        }
        ARSLineProgress.hide()
    }
    
    // MARK: - Private Methods
    
    // Creates a new instance of AGSMap and sets it to the mapView.
    private func setupMap() {
        mapView.locationDisplay.autoPanMode = .recenter
        //Start location services
        mapView.locationDisplay.start {error in
            DispatchQueue.main.async {
                if let error = error {
                    //If location services fails to work, just pick a point to start with
                    NSLog("ERROR: Error starting AGSLocationDisplay: \(error)")
                    self.mapView.map = AGSMap(basemapType: self.mapType, latitude: 40.615518, longitude: -74.026005, levelOfDetail: 0)
                } else {
                    //Else, set map to our current location
                    if let location = self.mapView.locationDisplay.location,
                        let lat = location.position?.y ,
                        let lon = location.position?.x {
                        
                        self.mapView.map = AGSMap(basemapType: self.mapType, latitude: lat, longitude: lon, levelOfDetail: 0)
                    } else {
                        //If No error occured but no location returned, pick a point to start
                        self.mapView.map = AGSMap(basemapType: self.mapType, latitude: 40.615518, longitude: -74.026005, levelOfDetail: 0)
                    }
                }
            }
        }
        mapView.touchDelegate = self
        let count = mapView.graphicsOverlays.count
        print("Graphic Overlay count: \(count)")
        if count == 0 {
        }else {
            mapView.graphicsOverlays.removeAllObjects()
        }
        mapView.graphicsOverlays.add(graphicsOverlay)
    }
    
    //Draw/Redraw the route line
    private func drawRouteLine() {
        guard let route = directionsController.mapAPIController.selectedRoute,
        let routeGeometry = route.routeGeometry else { return }
        if graphicsOverlay.graphics.count > 0 {
            graphicsOverlay.graphics.removeObject(at: 0)
        }
        let routeSymbol = AGSSimpleLineSymbol(style: .solid, color: self.routeLineColor, width: 4)
        let routeGraphic = AGSGraphic(geometry: routeGeometry, symbol: routeSymbol, attributes: nil)
        self.graphicsOverlay.graphics.insert(routeGraphic, at: 0)
    }
    
    // adds a mapmarker at a given location.
    private func addMapMarker(location: AGSPoint, style: AGSSimpleMarkerSymbolStyle, fillColor: UIColor, outlineColor: UIColor) {
        let pointSymbol = AGSSimpleMarkerSymbol(style: style, color: fillColor, size: 12)
        pointSymbol.outline = AGSSimpleLineSymbol(style: .solid, color: outlineColor, width: 2)
        let markerGraphic = AGSGraphic(geometry: location, symbol: pointSymbol, attributes: nil)
        graphicsOverlay.graphics.add(markerGraphic)
    }
    
    // MARK: - Selectors
    @objc func map_street () {
        self.mapType = .navigationVector
    }
    
    @objc func map_sat () {
        self.mapType = .imageryWithLabelsVector
    }
    
    @objc func map_ter () {
        self.mapType = .terrainWithLabelsVector
    }
    
    @objc func map_night () {
        self.mapType = .streetsNightVector
    }
    
    @objc private func logout() {
        logOutButtonTapped(self)
    }
}


// MARK: - Extensions
extension MapViewController: MenuDelegateProtocol {
    func performSelector(selector: Selector, with arg: Any?, waitUntilDone wait: Bool) {
        performSelector(onMainThread: selector, with: arg, waitUntilDone: wait)
    }
    
    func performSegue(segueIdentifier: String) {
        performSegue(withIdentifier: segueIdentifier, sender: self)
    }
}

extension MapViewController: AGSLocationChangeHandlerDelegate {
}
