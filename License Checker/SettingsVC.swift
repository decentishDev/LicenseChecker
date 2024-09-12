//
//  SettingsVC.swift
//  License Checker
//
//  Created by Matthew Lundeen on 9/8/24.
//

import UIKit

class SettingsVC: UIViewController {

    @IBOutlet weak var sizeSlider: UISlider!
    @IBOutlet weak var widthRatioField: UITextField!
    @IBOutlet weak var heightRatioField: UITextField!
    @IBOutlet weak var datasetButton: UIButton!
    
    let defaults = UserDefaults.standard
    
    var padding: CGFloat = 0.25
    var width: CGFloat = 2
    var height: CGFloat = 1
    var dataset: [[String]] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if let data = defaults.object(forKey: "settings") as? [String: Any]{
            padding = data["padding"]! as! CGFloat
            width = data["width"]! as! CGFloat
            height = data["height"]! as! CGFloat
            dataset = data["dataset"]! as! [[String]]
            sizeSlider.value = Float(1 - padding)
            widthRatioField.text = width.description
            heightRatioField.text = height.description
            if dataset.isEmpty {
                datasetButton.setTitle("Upload", for: .normal)
            }else{
                datasetButton.setTitle("Remove", for: .normal)
            }
        }else{
            padding = 0.25
            width =  2
            height = 1
            dataset = []
            save()
        }
    }
    
    @IBAction func sliderChanged(_ sender: UISlider) {
        
        padding = CGFloat(1 - sender.value)
        
        save()
    }
    
    @IBAction func widthChanged(_ sender: UITextField) {
        if let n = NumberFormatter().number(from: sender.text ?? "1") {
            width = CGFloat(truncating: n)
        }
        if width == 0 {
            width = 0.1
        }
        save()
    }
    
    @IBAction func heightChanged(_ sender: UITextField) {
        if let n = NumberFormatter().number(from: sender.text ?? "1") {
            height = CGFloat(truncating: n)
        }
        if height == 0 {
            height = 0.1
        }
        save()
    }
    
    @IBAction func datasetPressed(_ sender: UIButton) {
        if dataset.isEmpty {
            //upload file
        }else{
            dataset.removeAll()
            datasetButton.setTitle("Upload", for: .normal)
        }
        save()
    }
    
    func save(){
        defaults.set([
            "padding": padding,
            "width": width,
            "height": height,
            "dataset": dataset
        ], forKey: "settings")
    }
    
    @IBAction func cancel (_ unwindSegue: UIStoryboardSegue){
        
    }
}
