//
//  UIColor.swift
//  DashBoardNxTraq
//
//  Created by Jay Muthialu on 5/21/16.
//  Copyright © 2016 Nextraq. All rights reserved.
//

import Foundation
import UIKit

extension UIColor {
  
  func lightenColor(factor: CGFloat) -> UIColor {
    var r:CGFloat = 0, g:CGFloat = 0, b:CGFloat = 0, a:CGFloat = 0
    if self.getRed(&r, green: &g, blue: &b, alpha: &a){
       return UIColor(red: min(r + factor, 1.0), green: min(g + factor, 1.0), blue: min(b + factor, 1.0), alpha: a)
    }
    return self
  }
  
  func darkenColor(factor: CGFloat) -> UIColor {
    var r:CGFloat = 0, g:CGFloat = 0, b:CGFloat = 0, a:CGFloat = 0
    if self.getRed(&r, green: &g, blue: &b, alpha: &a){
      return UIColor(red: max(r - factor, 0.0), green: max(g - factor, 0.0), blue: max(b - factor, 0.0), alpha: a)
    }
    return self
  }
  
}
