//
//  HomeViewController.swift
//  MyLocalizedHome
//
//  Created by Julien Guillan on 04/01/2022.
//

import UIKit
import MapKit
import HomeKit
import CoreLocation

struct Address {
    var country: String!
    var postalCode: Int!
    var street: String!
    var number: Int!
    var city: String!
}

class HomeViewController: UIViewController {
    
    var homeManager: HMHomeManager!
    var primaryHome: HMHome!
    var relayPowerStateCharacteristic: HMCharacteristic!
    var thermometre: HMAccessory!
    var relay: HMAccessory!
    var humidityCharacteristic: HMCharacteristic!
    
    var locationManager: CLLocationManager!
    var home: HMHome!

    @IBOutlet var houseNameLabel: UILabel!
    @IBOutlet var tempValueLabel: UILabel!
    @IBOutlet var humValueLabel: UILabel!
    @IBOutlet var relaySwitch: UISwitch!
    @IBOutlet var lightsSwitch: UISwitch!
    @IBOutlet var mapView: MKMapView!
    
    var homeLocation: CLLocation!
    var homeAddress: Address!
    var currentAdress: Address!
    
    var currentSeconds: Int = 60
    var currentPlace: MKPointAnnotation!
    var homePlace: MKPointAnnotation!
    
    var limitTemp = 20.0
    var currentTemp: Double!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.homeManager = HMHomeManager()
        self.homeManager.delegate = self
        self.locationManager = CLLocationManager()
        self.locationManager.requestAlwaysAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            self.locationManager.delegate = self
            self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            self.locationManager.startUpdatingLocation()
            
            self.mapView.delegate = self
            
            //TMP for dev, à l'avenir, faire une entrée user pour sélectionner l'adresse du lieu principal
            self.homeLocation = self.locationManager.location
            self.getAddress(from: self.homeLocation){ addr in
                self.homeAddress = addr
                let latitude:CLLocationDegrees = self.homeLocation.coordinate.latitude
                let longitude:CLLocationDegrees = self.homeLocation.coordinate.longitude
                let latDelta:CLLocationDegrees = 0.05
                let lonDelta:CLLocationDegrees = 0.05
                let span = MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
                
                let home2DCoordinates = CLLocationCoordinate2DMake(latitude, longitude)
                let currentRegion = MKCoordinateRegion(center: home2DCoordinates, span: span)
                self.mapView.setRegion(currentRegion, animated: true)
                
                self.homePlace = self.createPlace(from: self.homeLocation, title: "home")
                self.mapView.addAnnotation(self.homePlace)
                self.initTimerRequests()
                self.restartHomeManager()
            }
            
        }
    }
    
    func createPlace(from location: CLLocation, title: String) -> MKPointAnnotation {
        let place = MKPointAnnotation()
        place.title = title
        place.coordinate = location.coordinate
        return place
    }
    
    func initTimerRequests() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.currentSeconds += 1
        }
    }
    
    func updateTemperature() {
        self.getValueFrom(accessory: self.thermometre, characteristicType: HMCharacteristicTypeCurrentTemperature) { val in
            guard let temperature = val else {
                return
            }
            let temp = temperature as! Double
            DispatchQueue.main.async {
                self.tempValueLabel.text = "\(String(temp))°c"
                self.currentTemp = temp
            }
        }
    }
    
    func updateHumidity() {
        self.getValueFrom(accessory: self.thermometre, characteristicType: HMCharacteristicTypeCurrentRelativeHumidity) { val in
            guard let humidity = val else {
                return
            }
            let hum = humidity as! Double
            DispatchQueue.main.async {
                self.humValueLabel.text = "\(String(hum))%"
            }
        }
    }
    
    func updateRelay() {
        self.getValueFrom(accessory: self.relay, characteristicType: HMCharacteristicTypePowerState) { val in
            DispatchQueue.main.async {
                let state = Bool(val as! Int == 1)
                self.relaySwitch.isOn = state
            }
            for service in self.relay.services {
                for characteristic in service.characteristics {
                    if characteristic.characteristicType == HMCharacteristicTypePowerState {
                        self.relayPowerStateCharacteristic = characteristic
                    }
                }
            }
        }
    }
    
    func restartHomeManager() {
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            self.homeManager = HMHomeManager()
            self.homeManager.delegate = self
            self.initAccessories()
            self.temperatureRule()
            print("Restarting homemanager...Ok")
        }
    }
    
    @IBAction func relaySwitchChanged(_ sender: Any) {
        if self.relaySwitch.isOn {
            writeValue(characteristic: self.relayPowerStateCharacteristic, value: 1)
        } else {
            writeValue(characteristic: self.relayPowerStateCharacteristic, value: 0)
        }
    }
    
    @IBAction func lightsSwitchChanged(_ sender: Any) {
        //To implement
    }
    
    @IBAction func editRelayRuleAction(_ sender: Any) {
        let rvc = RelayViewController.newInstance()
        navigationController?.pushViewController(rvc, animated: true)
    }
    
    @IBAction func editLightsRuleAction(_ sender: Any) {
        let lvc = LightsViewController.newInstance()
        navigationController?.pushViewController(lvc, animated: true)
    }
    
    func getValueFrom(accessory: HMAccessory, characteristicType: String, completion: @escaping(Any?) -> Void) -> Void {
        for service in accessory.services {
            for characteristic in service.characteristics {
                if characteristic.characteristicType == characteristicType {
                    characteristic.readValue { err in
                        if err != nil {
                            print("ERROR \(err!.localizedDescription)")
                        }
                    }
                    completion(characteristic.value)
                }
            }
        }
    }
    
    func writeValue(characteristic: HMCharacteristic, value: Int) -> Void {
        characteristic.writeValue(value, completionHandler: { err in
            if err != nil { print("ERROR writing value: ", err! ) }
        })
    }
    
    func initAccessories() -> Void {
        for accessory in self.primaryHome.accessories {
            accessory.delegate = self
            print(accessory.name)
            if accessory.name.contains("temp") {
                self.thermometre = accessory
                self.updateTemperature()
            } else if accessory.name.contains("hum") {
                if self.thermometre != nil {
                    self.updateHumidity()
                }
            } else if accessory.name.lowercased().contains("relais") {
                self.relay = accessory
                self.updateRelay()
            }
        }
    }
    
    func temperatureRule() {
        if self.currentTemp < self.limitTemp {
            self.writeValue(characteristic: self.relayPowerStateCharacteristic, value: 1)
        } else {
            self.writeValue(characteristic: self.relayPowerStateCharacteristic, value: 0)
        }
    }
    
    func getAddress(from location: CLLocation, completion: @escaping (Address) -> Void) -> Void {
        //limit to one request per minute for geocoder server
        if self.currentSeconds < 60 {
            //print("next authorized in \(60 - self.currentSeconds)s deso")
            return
        }
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { (infos, err) in
            if err != nil {
                print("Error while reversing \(location): ", err! )
                return
            }
            if infos == nil {
                return
            }
            let addresses = infos! as [CLPlacemark]
            let addr: CLPlacemark = addresses[0]
            var address: Address = Address()
            
            if addr.locality != nil {
                address.city = addr.locality
            }
            if addr.country != nil {
                address.country = addr.country
            }
            if addr.postalCode != nil {
                address.postalCode = Int(addr.postalCode!)
            }
            if addr.thoroughfare != nil {
                address.street = addr.thoroughfare
            }
            if addr.subThoroughfare != nil {
                address.number = Int(addr.subThoroughfare!)
            }
            self.currentSeconds = 0
            completion(address)
        }
    }

}

extension HomeViewController: CLLocationManagerDelegate, MKMapViewDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            self.getAddress(from: location) { addr in
                self.currentAdress = addr
            }
            if self.currentPlace != nil {
                self.mapView.removeAnnotation(self.currentPlace)
                self.currentPlace = self.createPlace(from: location, title: "Me")
                self.mapView.addAnnotation(self.currentPlace)
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: annotation.title ?? "place")
        if annotation.title == self.homePlace.title {
            annotationView.markerTintColor = .red
            annotationView.glyphText = self.homePlace.title
        } else {
            annotationView.markerTintColor = .blue
            annotationView.glyphText = "Me"
        }
        return annotationView
    }
}

extension HomeViewController: HMHomeManagerDelegate, HMHomeDelegate {
    
    //HOMEAMANGER DELEGATE
    func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        print("Updated Home")
    }
    
    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        print("update homes")
        self.homeManager = manager
        self.homeManager.delegate = self
        self.primaryHome = manager.homes.first
        self.primaryHome.delegate = self
        self.houseNameLabel.text = self.primaryHome.name
        self.initAccessories()
    }
}

extension HomeViewController: HMAccessoryDelegate {
    func accessory(_ accessory: HMAccessory, service: HMService, didUpdateValueFor characteristic: HMCharacteristic) {
        print("UPDATE", accessory.name)
        self.initAccessories()
        self.temperatureRule()
    }
}
