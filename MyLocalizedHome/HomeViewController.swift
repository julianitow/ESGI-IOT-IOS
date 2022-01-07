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

struct Address: CustomStringConvertible {
    var country: String!
    var postalCode: Int!
    var street: String!
    var number: Int!
    var city: String!
    var description: String { "\(self.number!) \(self.street!), \(self.city!), \(self.country!) \(self.postalCode!)"}
}

struct DefaultKeys {
    static let homeAddress = "HomeAddress"
    static let temperatureLimit = "TempLimit"
}

class HomeViewController: UIViewController {
    
    var homeManager: HMHomeManager!
    var primaryHome: HMHome!
    var relayPowerStateCharacteristic: HMCharacteristic!
    var thermometre: HMAccessory!
    var hygrometre: HMAccessory!
    var relay: HMAccessory!
    var humidityCharacteristic: HMCharacteristic!
    
    var parameters: UserDefaults!
    
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
    
    var currentSeconds = 60
    var currentPlace: MKPointAnnotation!
    var homePlace: MKPointAnnotation!
    
    var limitTemp = 20.0
    var currentTemp: Double!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.parameters = UserDefaults.standard
        self.homeManager = HMHomeManager()
        self.homeManager.delegate = self
        self.locationManager = CLLocationManager()
        self.locationManager.requestAlwaysAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            self.locationManager.delegate = self
            self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            
            self.mapView.delegate = self
            
            if let homeAddress = self.parameters.string(forKey: DefaultKeys.homeAddress) {
                print("Default address: \(homeAddress)")
                self.homeAddress = self.parseAddress(from: homeAddress)
                self.start()
            } else {
                self.setHomeAddress()
            }
            
            //TMP for dev, à l'avenir, faire une entrée user pour sélectionner l'adresse du lieu principal
            //self.homeLocation = self.locationManager.location
        }
    }
    
    func start() {
        if self.homeAddress != nil {
            self.getLocation(from: self.homeAddress) { location in
                self.homeLocation = location
                self.initMap()
                self.locationManager.startUpdatingLocation()
            }
        } else {
            self.getAddress(from: self.homeLocation){ addr in
                print("ADDRESS: \(addr)")
                self.homeAddress = addr
                self.initMap()
                self.locationManager.startUpdatingLocation()
            }
        }
    }
    
    func initMap() {
        let latitude:CLLocationDegrees = self.homeLocation.coordinate.latitude
        let longitude:CLLocationDegrees = self.homeLocation.coordinate.longitude
        let latDelta:CLLocationDegrees = 0.001
        let lonDelta:CLLocationDegrees = 0.001
        let span = MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        
        let home2DCoordinates = CLLocationCoordinate2DMake(latitude, longitude)
        let currentRegion = MKCoordinateRegion(center: home2DCoordinates, span: span)
        self.mapView.setRegion(currentRegion, animated: true)
        
        self.homePlace = self.createPlace(from: self.homeLocation, title: "home")
        self.mapView.addAnnotation(self.homePlace)
        
        self.mapView.setUserTrackingMode(MKUserTrackingMode.follow, animated: true)
        
        //TO MOVE ELSEWHERE
        self.initTimerRequests()
        self.initAccessories()
    }
    
    func parseAddress(from string: String) -> Address {
        let comaSplt = string.split(separator: ",")
        let splitCountryCP = comaSplt.last?.split(separator: " ")
        let country = String(splitCountryCP!.first!)
        let city = String(comaSplt[1])
        let codePostalStr = splitCountryCP!.last!
        let codePostal = Int(codePostalStr)
        
        let splitStreetNumber = comaSplt[0].split(separator: " ")
        let numberStr = splitStreetNumber[0]
        let number = Int(numberStr)
        
        var street = ""
        for i in 1...splitStreetNumber.count - 1 {
            street.append(contentsOf: splitStreetNumber[i])
            if i < splitStreetNumber.count - 1 {
                street.append(" ")
            }
        }
                
        let addr = Address(country: country, postalCode: codePostal, street: street, number: number, city: city)
        return addr
    }
    
    func setHomeAddress() {
        let alert = UIAlertController(title: "Setup", message: "Set the primary home address", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler:{ (UIAlertAction)in
                print("User click Dismiss button")
        }))
        
        alert.addTextField() { textField in
            textField.placeholder = "Country"
            textField.autocapitalizationType = .sentences
            textField.autocorrectionType = .yes
        }
        
        alert.addTextField() { textField in
            textField.placeholder = "City"
            textField.autocapitalizationType = .sentences
            textField.autocorrectionType = .yes
        }
        
        alert.addTextField() { textField in
            textField.placeholder = "postalCode"
            textField.keyboardType = .numberPad
        }
        
        alert.addTextField() { textField in
            textField.placeholder = "Street"
            textField.autocapitalizationType = .words
        }
        
        alert.addTextField() { textField in
            textField.placeholder = "number"
            textField.keyboardType = .numberPad
        }
        
        let useLocationAction = UIAlertAction(title: "Use current location", style: .default) { action in
            self.homeLocation = self.locationManager.location
            self.start()
        }
        
        let useAddressFormAction = UIAlertAction(title: "Save address", style: .default) { action in
            let country = alert.textFields![0].text
            let city = alert.textFields![1].text
            let postalCode = Int(alert.textFields![2].text!)
            let street = alert.textFields![3].text
            let number = Int(alert.textFields![4].text!)
            let addr = Address(country: country, postalCode: postalCode, street: street, number: number, city: city)
            self.homeAddress = addr
            self.parameters.set(addr.description, forKey: DefaultKeys.homeAddress)
            self.start()
        }
        
        for textField in alert.textFields! {
            textField.addTarget(self, action: #selector(self.textChanged), for: .editingChanged)
        }
        
        alert.addAction(useAddressFormAction)
        alert.addAction(useLocationAction)
        alert.actions[1].isEnabled = false
        
        self.present(alert, animated: true) {
            
        }
    }
    
    @objc func textChanged(sender: AnyObject) {
        print("TEXT CHANGED")
        var textInput = 0
        let textField = sender as! UITextField
        var resp: UIResponder = textField
        while !(resp is UIAlertController) {
            if resp.next != nil {
                resp = resp.next!
            }
        }
        let alert = resp as! UIAlertController
        for textField in alert.textFields! {
            if textField.text!.count > 0 {
                textInput += 1
            }
        }
        if textInput == 5 {
            alert.actions[1].isEnabled = true
        } else {
            alert.actions[1].isEnabled = false
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
            self.tempValueLabel.text = "\(String(temp))°c"
            self.currentTemp = temp
        }
    }
    
    func updateHumidity() {
        self.getValueFrom(accessory: self.hygrometre, characteristicType: HMCharacteristicTypeCurrentRelativeHumidity) { val in
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
    
    func restartHomeManager(manager: HMHomeManager? = nil) {
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            if manager != nil {
                self.homeManager = manager
            } else {
                self.homeManager = HMHomeManager()
            }
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
        print(accessory.name)
        for service in accessory.services {
            for characteristic in service.characteristics {
                if characteristic.characteristicType == characteristicType {
                    print(accessory.name)
                    characteristic.readValue { err in
                        if err != nil {
                            print("ERROR \(accessory.name): \(err!.localizedDescription)")
                        }
                    }
                    completion(characteristic.value)
                }
            }
        }
    }
    
    func writeValue(characteristic: HMCharacteristic, value: Int) -> Void {
        print(characteristic.characteristicType)
        characteristic.writeValue(value, completionHandler: { err in
            if err != nil { print("ERROR writing value: ", err! ) }
        })
    }
    
    func initAccessories() -> Void {
        for accessory in self.primaryHome.accessories {
            accessory.delegate = self
            if accessory.name.contains("temp") {
                self.thermometre = accessory
                self.updateTemperature()
            } else if accessory.name.contains("hum") {
                self.hygrometre = accessory
                self.updateHumidity()
            } else if accessory.name.lowercased().contains("relais") {
                self.relay = accessory
                self.updateRelay()
            }
        }
    }
    
    func temperatureRule() {
        if self.relay.isReachable {
            if self.currentTemp < self.limitTemp {
                self.writeValue(characteristic: self.relayPowerStateCharacteristic, value: 1)
            } else {
                self.writeValue(characteristic: self.relayPowerStateCharacteristic, value: 0)
            }
        } else {
            print("ERROR: relay not reachable")
        }
    }
    
    func getLocation(from address: Address, completion: @escaping (CLLocation) -> Void) -> Void {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(self.homeAddress.description) { (placemarks, err) in
            let alert = UIAlertController(title: "Something wrong", message: "Please check your address", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok !", style: .default) { action in
                self.homeAddress = nil
                self.setHomeAddress()
            })
            if err != nil {
                print("ERROR", err?.localizedDescription)
                self.present(alert, animated: true) {
                    
                }
                return
            }
            if placemarks == nil {
                print("ERROR placemarks nil")
                self.present(alert, animated: true) {
                    
                }
            }
            
            let location = placemarks?.first?.location
            completion(location!)
        }
    }
    
    func getAddress(from location: CLLocation, completion: @escaping (Address) -> Void) -> Void {
        //limit to one request per minute for geocoder server
        print("REQUESTING ADDRESS FROM LOC")
        if self.currentSeconds < 60 {
            print("next authorized in \(60 - self.currentSeconds)s deso")
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
            var annotations: [MKPointAnnotation] = []
            if self.currentPlace != nil {
                self.mapView.removeAnnotation(self.currentPlace)
            }
            
            if location == self.homeLocation {
                print("LOCATION HOME")
            }
            self.currentPlace = self.createPlace(from: location, title: "Me")
            annotations.append(self.currentPlace)
            self.mapView.addAnnotations(annotations)
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: annotation.title ?? "place")
        if annotation.title == "home" {
            annotationView.markerTintColor = .red
            annotationView.glyphText = "home"
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
        print("Updated Home", status)
    }
    
    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        print("update homes")
        self.restartHomeManager(manager: manager)
        self.primaryHome = self.homeManager.homes.first
        self.primaryHome.delegate = self
        self.houseNameLabel.text = self.primaryHome.name
    }
}

extension HomeViewController: HMAccessoryDelegate {
    func accessory(_ accessory: HMAccessory, service: HMService, didUpdateValueFor characteristic: HMCharacteristic) {
        print("UPDATE", accessory.name)
        self.initAccessories()
        self.temperatureRule()
    }
}
