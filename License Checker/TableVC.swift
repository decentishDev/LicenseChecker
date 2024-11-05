//
//  TableVC.swift
//  License Checker
//
//  Created by Matthew Lundeen on 11/4/24.
//

import UIKit

class TableVC: UIViewController {

    @IBOutlet weak var stackView: UIStackView!
    var data: [[String]] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        
        stackView.distribution = .fillEqually
        stackView.spacing = 8
        

        if let data = UserDefaults.standard.object(forKey: "settings") as? [String: Any]{
            let data = data["dataset"]! as! [[String]]
            if !data.isEmpty {
                self.data = data
            }
            
        }
        
        print(data[0])
        
        let rows = transpose(array: data)
        
        for row in rows {
            let rowStackView = UIStackView()
            rowStackView.axis = .horizontal
            rowStackView.distribution = .fillEqually
            rowStackView.spacing = 8
            
            for cell in row {
                let label = UILabel()
                label.text = cell
                label.textAlignment = .center
                rowStackView.addArrangedSubview(label)
            }
            stackView.addArrangedSubview(rowStackView)
        }
    }
    
    func transpose(array: [[String]]) -> [[String]] {
        guard let firstRow = array.first else { return [] }
        return firstRow.indices.map { index in
            array.map {$0[index]}
        }
    }
    

    @IBAction func cancel (_ unwindSegue: UIStoryboardSegue){
        
    }

}
