//
//  DemoChartVC.swift
//  DemoChart
//
//  Created by Jay Muthialu on 9/5/16.
//  Copyright © 2016 gpod. All rights reserved.
//

import UIKit
import Chart

class DemoChartVC: UIViewController, chartProtocol {

  @IBOutlet var orderChartView: DoughNutChart!
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    orderChartView.delegate = self
    orderChartView.segmentDataArray = [20, 34, 80]
    let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(DemoChartVC.viewTapped))
    self.view.addGestureRecognizer(tapRecognizer)
  }
  
  func chartSegmentClicked(sender: AnyObject, segmentClicked: Int) {
    print("segment clicked: \(segmentClicked)")
  }
  
  func viewTapped() {
    orderChartView.clearSelection()
  }
  

}

