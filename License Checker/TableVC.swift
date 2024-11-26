import UIKit

class TableVC: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    
    var backButton: UIButton!
    var backImage: UIImageView!
    var data: [[String]] = []
    var rows: [[String]] = []
    var filteredRows: [[String]] = []
    private let tableView = UITableView()
    private let scrollView = UIScrollView()
    private let searchBar = UISearchBar()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let settings = UserDefaults.standard.object(forKey: "settings") as? [String: Any],
           let dataset = settings["dataset"] as? [[String]], !dataset.isEmpty {
            self.data = dataset
        }
        
        rows = transpose(array: data)
        filteredRows = rows
        
        let safeAreaInsets = self.view.safeAreaInsets
        //let safeTop = safeAreaInsets.top
        let safeTop = UserDefaults.standard.object(forKey: "topPadding") as! CGFloat
        let screenWidth = UIScreen.main.bounds.width
        
        let searchBarHeight: CGFloat = 50
        searchBar.frame = CGRect(
            x: 10,
            y: safeTop + 10,
            width: screenWidth - 70,
            height: searchBarHeight
        )
        searchBar.delegate = self
        searchBar.placeholder = "License plate or other data"
        searchBar.searchTextField.backgroundColor = .secondarySystemBackground // Set the desired background color
        searchBar.searchTextField.layer.borderWidth = 0    // Remove the border
        searchBar.searchTextField.layer.cornerRadius = 10  // Optional: Add some rounding to match modern UI styles
        searchBar.backgroundImage = UIImage()             // Remove the background image to eliminate outlines
        searchBar.layer.borderWidth = 0                   // Remove outer border if present

        view.addSubview(searchBar)
        
        let buttonSize: CGFloat = 40
        backButton = UIButton(frame: CGRect(
            x: screenWidth - 50,
            y: safeTop + 15,
            width: buttonSize,
            height: buttonSize
        ))
        backButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        backButton.addTarget(self, action: #selector(self.tableUnwind(sender:)), for: .touchUpInside)
        view.addSubview(backButton)
        
        scrollView.frame = CGRect(
            x: 0,
            y: searchBar.frame.maxY + 10,
            width: screenWidth,
            height: view.frame.height - (searchBar.frame.maxY + 10)
        )
        view.addSubview(scrollView)
        
        tableView.frame = CGRect(
            x: 0,
            y: 0,
            width: CGFloat(rows.first?.count ?? 0) * 150.0,
            height: CGFloat(rows.count) * 50.0
        )
        tableView.delegate = self
        tableView.dataSource = self
        tableView.isScrollEnabled = false
        tableView.register(SpreadsheetCell.self, forCellReuseIdentifier: "SpreadsheetCell")
        scrollView.addSubview(tableView)
        
        scrollView.contentSize = tableView.frame.size
        
        // Add tap gesture recognizer
        let gesture = UITapGestureRecognizer(target: self, action: #selector(touchBackground(_:)))
        view.addGestureRecognizer(gesture)
    }


    
    @objc func touchBackground(_ sender: UITapGestureRecognizer){
        searchBar.resignFirstResponder()
    }
    
    @objc func tableUnwind(sender: UIButton){
        performSegue(withIdentifier: "tableUnwind", sender: nil)
    }

    func transpose(array: [[String]]) -> [[String]] {
        guard let firstRow = array.first else { return [] }
        return firstRow.indices.map { index in
            array.map { $0[index] }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredRows.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SpreadsheetCell", for: indexPath) as! SpreadsheetCell
        
        let rowData = filteredRows[indexPath.row]
        cell.configure(with: rowData)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        let normalizedSearchText = searchText.replacingOccurrences(of: " ", with: "").lowercased()
        
        if normalizedSearchText.isEmpty {
            filteredRows = rows
        } else {
            filteredRows = rows.filter { row in
                row.contains { $0.replacingOccurrences(of: " ", with: "").lowercased().contains(normalizedSearchText) }
            }
        }
        tableView.reloadData()
        
        scrollView.setContentOffset(CGPoint(x: 0, y: 0), animated: true)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        
        if let searchText = searchBar.text, !searchText.isEmpty {
            let normalizedSearchText = searchText.replacingOccurrences(of: " ", with: "").lowercased()
            
            if let index = filteredRows.firstIndex(where: { row in
                row.contains { $0.replacingOccurrences(of: " ", with: "").lowercased().contains(normalizedSearchText) }
            }) {
                let indexPath = IndexPath(row: index, section: 0)
                tableView.scrollToRow(at: indexPath, at: .top, animated: true)
            }
        }
    }

    
    @IBAction func cancel(_ unwindSegue: UIStoryboardSegue) {
    }
}

class SpreadsheetCell: UITableViewCell {
    
    private var labels: [UILabel] = []
    private let stackView = UIStackView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupStackView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupStackView() {
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.spacing = 1
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }
    
    func configure(with row: [String]) {
        labels.forEach { $0.removeFromSuperview() }
        labels = []
        
        for text in row {
            let label = UILabel()
            label.text = text
            label.font = UIFont.systemFont(ofSize: 14)
            label.textAlignment = .center
            label.numberOfLines = 1
            labels.append(label)
            stackView.addArrangedSubview(label)
        }
    }
}
