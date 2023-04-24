//
//  ViewController.swift
//  single-HLS-To-MultiView
//
//  Created by Manasa M P on 06/04/23.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let view1 = TestView()
        view1.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(view1)
        NSLayoutConstraint.activate([
            view1.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view1.topAnchor.constraint(equalTo: view.topAnchor),
            view1.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            view1.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
}
