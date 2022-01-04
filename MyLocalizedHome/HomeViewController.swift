//
//  HomeViewController.swift
//  MyLocalizedHome
//
//  Created by Julien Guillan on 04/01/2022.
//

import UIKit
import HomeKit

class HomeViewController: UIViewController {
    
    var homeManager: HMHomeManager!
    var primaryHome: HMHome!

    @IBOutlet var houseNameLabel: UILabel!
    @IBOutlet var tempValueLabel: UILabel!
    @IBOutlet var humValueLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let manager = HMHomeManager()
        self.homeManager = manager
        manager.delegate = self
    }
    
    
    func getValueFrom(accessory: HMAccessory, characteristicType: String) -> Any? {
        for service in accessory.services {
            for characteristic in service.characteristics {
                if characteristic.characteristicType == characteristicType {
                    guard let value = characteristic.value else {
                        return nil
                    }
                    return value
                    //let val = String(value as! Double)
                    //self.tempValueLabel.text = val
                }
            }
        }
        return nil
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
        for accessory in self.primaryHome.accessories {
            if accessory.name.contains("temp") {
                let value = self.getValueFrom(accessory: accessory, characteristicType: HMCharacteristicTypeCurrentTemperature) as! Double
                self.tempValueLabel.text = String(value)
            } else if accessory.name.contains("hum") {
                let value = self.getValueFrom(accessory: accessory, characteristicType: HMCharacteristicTypeCurrentRelativeHumidity) as! Int
                self.humValueLabel.text = String(value)
            }
        }
    }
}
