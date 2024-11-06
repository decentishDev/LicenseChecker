import UIKit

class TableVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var backImage: UIImageView!
    var data: [[String]] = []
    var rows: [[String]] = []
    
    private let tableView = UITableView()
    private let scrollView = UIScrollView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Load dataset from UserDefaults
        if let settings = UserDefaults.standard.object(forKey: "settings") as? [String: Any],
           let dataset = settings["dataset"] as? [[String]], !dataset.isEmpty {
            self.data = dataset
        }
        
        // Transpose the data for correct row/column layout
        rows = transpose(array: data)
        
        // Configure the scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        // Configure the table view
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.isScrollEnabled = false // Disable internal scrolling to allow UIScrollView control
        
        // Register a custom cell
        tableView.register(SpreadsheetCell.self, forCellReuseIdentifier: "SpreadsheetCell")
        
        scrollView.addSubview(tableView)
        
        // Set content size of scroll view based on data
        let contentWidth = CGFloat(rows.first?.count ?? 0) * 100.0 // Adjust 100.0 to fit your preferred cell width
        let contentHeight = CGFloat(rows.count) * 44.0 // 44.0 is a standard cell height
        
        scrollView.contentSize = CGSize(width: contentWidth, height: contentHeight)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 100),
            tableView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            tableView.widthAnchor.constraint(equalToConstant: contentWidth),
            tableView.heightAnchor.constraint(equalToConstant: contentHeight)
        ])
        
        backImage.removeFromSuperview()
        view.addSubview(backImage)
        backButton.removeFromSuperview()
        view.addSubview(backButton)
    }
    
    func transpose(array: [[String]]) -> [[String]] {
        guard let firstRow = array.first else { return [] }
        return firstRow.indices.map { index in
            array.map { $0[index] }
        }
    }
    
    // MARK: - TableView DataSource Methods
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SpreadsheetCell", for: indexPath) as! SpreadsheetCell
        
        // Configure cell with row data
        let rowData = rows[indexPath.row]
        cell.configure(with: rowData)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }
    
    @IBAction func cancel (_ unwindSegue: UIStoryboardSegue){
        
    }
}

// Custom UITableViewCell for spreadsheet-style layout
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
        // Remove old labels
        labels.forEach { $0.removeFromSuperview() }
        labels = []
        
        // Add new labels for each column in the row
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
