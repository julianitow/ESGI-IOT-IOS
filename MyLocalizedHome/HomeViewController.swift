//
//  HomeViewController.swift
//  MyLocalizedHome
//
//  Created by Julien Guillan on 04/01/2022.
//

import UIKit
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
    
    var locationManager: CLLocationManager!

    @IBOutlet var houseNameLabel: UILabel!
    @IBOutlet var tempValueLabel: UILabel!
    @IBOutlet var humValueLabel: UILabel!
    @IBOutlet var relaySwitch: UISwitch!
    
    var homeLocation: CLLocation!
    var homeAddress: Address!
    var currentAdress: Address!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.homeManager = HMHomeManager()
        
        self.locationManager = CLLocationManager()
        self.locationManager.requestAlwaysAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            self.locationManager.delegate = self
            self.locationManager.delegate = self
            self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            self.locationManager.startUpdatingLocation()
            
            //TMP for dev
            self.homeLocation = self.locationManager.location
            self.getAddress(from: self.homeLocation) { addr in
                self.homeAddress = addr
            }
        }
    }
    
    @IBAction func relaySwitchChanged(_ sender: Any) {
        if self.relaySwitch.isOn {
            writeValue(characteristic: self.relayPowerStateCharacteristic, value: 1)
        } else {
            writeValue(characteristic: self.relayPowerStateCharacteristic, value: 0)
        }
    }
    
    func getValueFrom(accessory: HMAccessory, characteristicType: String) -> Any? {
        for service in accessory.services {
            for characteristic in service.characteristics {
                if characteristic.characteristicType == characteristicType {
                    guard let value = characteristic.value else {
                        return nil
                    }
                    return value
                }
            }
        }
        return nil
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
                let value = self.getValueFrom(accessory: accessory, characteristicType: HMCharacteristicTypeCurrentTemperature) as! Double
                self.tempValueLabel.text = String(value)
            } else if accessory.name.contains("hum") {
                let value = self.getValueFrom(accessory: accessory, characteristicType: HMCharacteristicTypeCurrentRelativeHumidity) as! Int
                self.humValueLabel.text = String(value)
            } else if accessory.name.lowercased().contains("relais") {
                for service in accessory.services {
                    for characteristic in service.characteristics {
                        if characteristic.characteristicType == HMCharacteristicTypePowerState {
                            let value = characteristic.value as! Int
                            let val = Bool(value == 1)
                            self.relaySwitch.isOn = val
                            self.relayPowerStateCharacteristic = characteristic
                        }
                    }
                }
            }
        }
    }
    
    func getAddress(from location: CLLocation, completion: @escaping (Address) -> Void) -> Void {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { (infos, err) in
            if err != nil {
                print("Error while reversing location: ", err! )
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
            completion(address)
        }
    }

}

extension HomeViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            self.getAddress(from: location) { addr in
                self.currentAdress = addr
            }
        }
    }
}

extension HomeViewController: HMHomeManagerDelegate {
    func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        print("Updated Home")
    }
    
    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        print("update homes")
        self.primaryHome = manager.homes.first
        self.houseNameLabel.text = self.primaryHome.name
        self.initAccessories()
    }
}

extension HomeViewController: HMAccessoryDelegate {
    func accessory(_ accessory: HMAccessory, service: HMService, didUpdateValueFor characteristic: HMCharacteristic) {
        print("UPDATE", accessory.name)
        self.initAccessories()
    }
}
