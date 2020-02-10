//
//  AGSMapAPIController.swift
//  RVNav
//
//  Created by Lambda_School_Loaner_214 on 1/21/20.
//  Copyright © 2020 RVNav. All rights reserved.
//

import UIKit
import ArcGIS

enum MapAPIControllerError: Error {
    case errorGettingAvoidances(String)
    case noAvoidancesReturned
    case noRouteParameters
    case noBarriersReturned
    case errorFetchingRoute
}

class AGSMapAPIController: NSObject, MapAPIControllerProtocol, AGSGeoViewTouchDelegate {
    
    // MARK: - Properties
    var delegate: ViewDelegateProtocol?
    internal var avoidanceController: AvoidanceControllerProtocol
    private let routeTask = AGSRouteTask(url: URL(string: "https://route.arcgis.com/arcgis/rest/services/World/Route/NAServer/Route_World")!)
    var geoCoder = AGSLocatorTask(url:URL(string: "https://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer")!)
    var selectedRoute: AGSRoute?{
        didSet{
            NotificationCenter.default.post(name: .routeNeedsMapped, object: self)
        }
    }
    
    // MARK: -  Lifecycle
    required init(avoidanceController: AvoidanceControllerProtocol) {
        self.avoidanceController = avoidanceController
        super.init()
        setupArcGISCredential()
    }
    
    //Sets up credentials to access ArcGIS Routing with OURS
    func setupArcGISCredential() {
        let portal:AGSPortal = AGSPortal.arcGISOnline(withLoginRequired: false)
        let clientId = "taIMz5a6FZ8j6ZCs"; #warning("Store credentials securly")
        let clientSecret = "42694cda208b4c95b7c07673ca877f92"
        portal.getAppIDToken(clientId: clientId, clientSecret: clientSecret) { (credential, error) in
            guard error == nil else {
                print("Could not get credential! \(error!.localizedDescription)")
                return
            }
            print("Got a credential: \(credential!)")
        }
    }
    
    // MARK: - Public Methods
    func search(with address: String, completion: @escaping ([AGSGeocodeResult]?) -> Void) {
        geoCoder.geocode(withSearchText: address) { (results, error) in
            if let error = error {
                NSLog("Error geocoding address to placemarks: \(error)")
                completion(nil)
                return
            }
            if let results  = results {
                completion(results)
                return
            }
        }
    }
    
    func fetchRoute(from routeInfo: RouteInfo, completion: @escaping (AGSRoute?, Error?) -> Void) {
        
        fetchBarriers(from: routeInfo) { (barriers, error) in
            if let error = error {
                completion(nil,error)
                return
            }
            
            guard let barriers = barriers else {
                completion(nil, MapAPIControllerError.noBarriersReturned)
                return
            }
            
            self.routeTask.defaultRouteParameters { [weak self] (defaultParameters, error) in
                guard error == nil else {
                    print("Error getting default parameters: \(error!.localizedDescription)")
                    completion(nil, MapAPIControllerError.noRouteParameters)
                    return
                }
                let startCLCoordinate = CLLocationCoordinate2D(latitude: routeInfo.startLat, longitude: routeInfo.startLon)
                let endCLCoordinate = CLLocationCoordinate2D(latitude: routeInfo.endLat, longitude: routeInfo.endLon)
                let startPoint = AGSPoint(clLocationCoordinate2D: startCLCoordinate)
                let endPoint = AGSPoint(clLocationCoordinate2D: endCLCoordinate)
                
                guard let params = defaultParameters, let self = self else { return }
                
                //Clear in case we're re-calling this after map has a route
                params.clearStops()
                //Setup the names of the stop with Addresses from SelectRoute
                let startStop = AGSStop(point: startPoint)
                startStop.name = routeInfo.startName
                let endStop = AGSStop(point: endPoint)
                endStop.name = routeInfo.endName
                params.setStops([startStop, endStop])
                params.clearPolygonBarriers()
                params.setPolygonBarriers(barriers)
                params.returnDirections = true
                params.returnStops = true
                //Force unwrapping below becuase it wouldn't autocomplete and the enum case in documentation errored out: Wanting Imperial vs. Metric, using rawValue here returns optional
                let unitSystem = AGSUnitSystem(rawValue: 0)!
                params.directionsDistanceUnits = unitSystem
                
                self.routeTask.solveRoute(with: params){ (result, error) in
                    guard error == nil else {
                        print("Error solving route: \(error!.localizedDescription)")
                        completion(nil, error)
                        return
                    }
                    #warning("Do we want to offer a list of routes to choose from?")
                    if let firstRoute = result?.routes.first {
                        self.printRoute(with: firstRoute)
                        completion (firstRoute,nil)
                    }
                }
            }
        }
    }
    
    
    /*
     The addresses used here:
     1119 S Summit St, Little Rock Arkansas
     1923 W 10th st, Little Rock Arkansas
     
     They demonstrate routing around low clearance well and quickly.
     */
    public func testRoute() {
        let startCoord = CLLocationCoordinate2D(latitude: 34.740070, longitude: -92.295000)
        let endCoord = CLLocationCoordinate2D(latitude: 34.741428, longitude: -92.294998)
        
        let vehicle = Vehicle(id: 2, name: "Big Jim", height: 13, weight: 5555.0, width: 10.0, length: 38.0, axelCount: 3, vehicleClass: "Class A", dualTires: true, trailer: nil)
        let routeInfo = RouteInfo(height: vehicle.height!, startName: "Test Start", startLon: startCoord.longitude, startLat: startCoord.latitude, endName: "Test End", endLon: endCoord.longitude, endLat: endCoord.latitude)
        
        ARSLineProgress.show()
        fetchRoute(from: routeInfo) { (route, error) in
            if let error = error {
                ARSLineProgress.showFail()
                print("ASGMapAPIController - Error gettign route: \(error)")
                return
            }
            if let route = route {
                self.selectedRoute = route
            }
            ARSLineProgress.hide()
        }
    }
    
    // MARK: - Private Methods
    private func fetchBarriers(from route: RouteInfo, completion: @escaping ([AGSPolygonBarrier]?, MapAPIControllerError?) -> Void) {
        avoidanceController.getAvoidances(with: route) { (avoidances, error) in
            var barriers: [AGSPolygonBarrier] = []
            let const = 0.0001
            
            if let error = error {
                NSLog("Error fetching avoidances:\(error)")
                completion(nil, .errorGettingAvoidances("Error fetching avoidances:\(error)"))
                return
            }
            guard let avoidances = avoidances else {
                completion(nil,.noAvoidancesReturned)
                return
            }
            for avoid in avoidances {
                let point = AGSPoint(clLocationCoordinate2D: CLLocationCoordinate2D(latitude: (avoid.latitude + const), longitude: (avoid.longitude + const)))
                let point1 = AGSPoint(clLocationCoordinate2D: CLLocationCoordinate2D(latitude: (avoid.latitude + const), longitude: (avoid.longitude - const)))
                let point2 = AGSPoint(clLocationCoordinate2D: CLLocationCoordinate2D(latitude: (avoid.latitude - const), longitude: (avoid.longitude - const)))
                let point3 = AGSPoint(clLocationCoordinate2D: CLLocationCoordinate2D(latitude: (avoid.latitude - const), longitude: (avoid.longitude + const)))
                let gon = AGSPolygon(points: [point, point1, point2, point3])
                let barrier = AGSPolygonBarrier(polygon: gon)
                
                barriers.append(barrier)
            }
            completion(barriers, nil)
        }
    }
    
    private func printRoute(with route: AGSRoute) {
        let timeInSeconds: Double = route.totalTime * 60
        print ("Total Time: \(timeInSeconds.asString(style: .short))")
        let lengthString: String = route.totalLength.fromMetersToImperialString()
        print ("Total Length: " + lengthString)
        print ("***Stops***")
        for stop in route.stops.sorted(by: { (lhs, rhs) -> Bool in
            return lhs.sequence < rhs.sequence
        }) {
            print("Stop \(stop.sequence): name: \(stop.name) for route \(stop.routeName)  ")
        }
        print ("  ***Maneuvers***")
        for maneuver in route.directionManeuvers {
            print ("    Maneuver text: \(maneuver.directionText)")
            print ("    Maneuver lenght: \(maneuver.length.fromMetersToImperialString())")
            print ("      Messages:")
            for message in maneuver.maneuverMessages {
                print ("           message: \(message.text)  type: \(String(describing: message.type))")
            }
            print ("    Maneuver type: \(String(describing: maneuver.maneuverType))")
        }
    }
}
