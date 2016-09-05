//
//  DoughNutChart.swift
//
//  Created by Jay Muthialu on 5/21/16.
//  Copyright © 2016 Nextraq. All rights reserved.
//
// Class Behavior
//
// Entry Point: Provide data array in CGFloat.
// Exit point: Draws chart using the data points provided. Legends are converted into Int for display purpose.
//             Sum of the data points are displayed in the center.
//
// Any segments clicked are delegated to doughNutChartProtocol .
// The radius of the doughtnut chart is derived from the view frame size after netting out label margins
// BottomMargin and labelMargin and within frame.width/2
// View frame hieght should be frame.width / 2 at a minimum.
// doughNutRadius; Outer radius of the doughNut.
// doughNutMidRadius: doughNutRadius - doughNutWidth / 2
// Pushout logic:
//  pushOut is used to indicate if the label should be pushed out because the segment is too small
//  A. It calculates the minimum radians needed to display label
//  B. Iterates through segmentGeometricValues and checks if the segment should be 
//      pushed out and store the pushOutStatus in the segmentGeometricValues. 
//      The first segment will not be pushed out and the next segment if the segment is small it checks if the previous segment has been pushed out
//      if not the it will push the current segment, if not it will not push out.
//  C. Does not show the label which has been pushedout. Tried by moving the labels but the appearance did not look good
//

import UIKit

public protocol chartProtocol: class {
  func chartSegmentClicked(sender: AnyObject, segmentClicked: Int)
}

@IBDesignable public class DoughNutChart: UIView {
    
  @IBInspectable var doughNutWidth: CGFloat = 0.0
  @IBInspectable var innerRingWidth: CGFloat = 0.0
  @IBInspectable var segment1Color: UIColor = UIColor.redColor()
  @IBInspectable var segment2Color: UIColor = UIColor.redColor()
  @IBInspectable var segment3Color: UIColor = UIColor.redColor()
  @IBInspectable var segment4Color: UIColor = UIColor.redColor()
  @IBInspectable var segment5Color: UIColor = UIColor.redColor()
  @IBInspectable var labelMargin: CGFloat = 30.0 //margin between outer ring and label. 
                                                // While drawing labels labelMargin / 2 is used to center the label in the LabelMargin zone
  @IBInspectable var bottomMargin: CGFloat = 20.0 //margin between view bottom and bottom of chart
  @IBInspectable var labelFontSize: CGFloat = 15.0
  @IBInspectable var labelFontColor: UIColor = UIColor.darkGrayColor()
  @IBInspectable var centerLabelFontSize: CGFloat = 17.0
  
  public var segmentDataArray: [CGFloat] =  [23, 45, 34]  // Default values passed to the chart
  weak public var delegate: chartProtocol?
  public var segmentColors = [UIColor]() //Default Colors from storyboard.
  public var segmentColorsCustom: [UIColor]? //Custom colors passed by delegate which will override default colors
  private var segmentSelected: Int = -1 //Segment selected by user. -1 if no segments are selected.
  private var centerPoint = CGPointMake(0, 0)
  private var doughNutMidRadius: CGFloat = 0.0
  private var doughNutOuterRadius: CGFloat = 0.0
  private var minRadiansNeededForLabels: CGFloat = 0.0
  private var pushOutLabelMargin: CGFloat = 0.0 //Margin used to push out labels
  private var errorLabel = UILabel()
  private var segmentLabelQueue = [UILabel]()
  
  private let M_PI_CGFloat = CGFloat(M_PI)
  private let segmentSeperatorGap: CGFloat = 0 // in radians Ex: 0.05
  private let kColorDarkenFactor: CGFloat = 0.25
  private let kDoughNutWidthFactor: CGFloat = 0.55 //Used to find the doughnut width from doughnut outer radius
  private let kFontSizeFactor: CGFloat = 0.15 //Used to determine font size from doughnut outer radius
  private let kNotEnoughColorsDefined = "Colors not defined for all data values."
  private let kDataZeroError = "" //"Data sums to zero. Cannot draw chart"
  
  private struct SegmentGeometryStruct {
    var index: Int = -1
    var chartData: CGFloat = 0
    var startRadian: CGFloat = 0.0
    var endRadian: CGFloat = 0.0
    var segmentColor: UIColor = UIColor.clearColor()
    var pushOut: Bool = false
  }
  private var segmentGeometricValues = [SegmentGeometryStruct]()
  
  override public func awakeFromNib() {
    super.awakeFromNib()
    let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(DoughNutChart.viewTapped(_:)))
    tapRecognizer.cancelsTouchesInView = false
    self.addGestureRecognizer(tapRecognizer)
    
    if UIDevice.currentDevice().userInterfaceIdiom == UIUserInterfaceIdiom.Pad {
      labelFontSize = 13.0
    }
    
    //  Setup Error Label
    let rectSize = self.frame.size
    let errorLabelCenter = CGPoint(x: centerPoint.x, y: rectSize.height / 2)
    let errorLabelFrame = CGRectMake(0.0, 0.0, rectSize.width, labelFontSize)
    errorLabel.frame = errorLabelFrame
    errorLabel.center = errorLabelCenter
    errorLabel.textAlignment = NSTextAlignment.Center
    errorLabel.hidden = true
    errorLabel.text = ""
    self.addSubview(errorLabel)
  }
  
// Initializes segmentGeometricValues, validates colors are defined for all data elements, initializes labelPool
  private func initializeValues(rectSize: CGSize) -> Bool {
    var segmentStartRadian: CGFloat = M_PI_CGFloat
    var segmentEndRadian: CGFloat = 0.0
    
    centerPoint = CGPoint(x: rectSize.width / 2, y: rectSize.height - bottomMargin)
    doughNutOuterRadius = (rectSize.width - (labelMargin * 2.0)) / 2
    doughNutWidth = doughNutOuterRadius * kDoughNutWidthFactor
    doughNutMidRadius = doughNutOuterRadius - doughNutWidth / 2
    pushOutLabelMargin = labelFontSize * 0.5 //Label font size is reduced by 50% so that it does not push out labels which has room to display
    
    minRadiansNeededForLabels = minRadiansForLabels(pushOutLabelMargin)
    
    let errorLabelCenter = CGPoint(x: centerPoint.x, y: rectSize.height / 2)
    segmentColors = [segment1Color, segment2Color, segment3Color, segment4Color, segment5Color]

    for labelInQueue in segmentLabelQueue {
      labelInQueue.removeFromSuperview()
    }
    segmentLabelQueue.removeAll()
    
//  Validate if colors are defined for all the data elements
    let segmentsSum = segmentDataArray.reduce(0.0, combine: { $0 + $1 })
    //  Setup Segment colors
    if let segmentColorsCustom = segmentColorsCustom where segmentColorsCustom.count >= segmentDataArray.count {
        segmentColors = segmentColorsCustom
        errorLabel.text = ""
        errorLabel.hidden = true
    } else if segmentColors.count < segmentDataArray.count {
        errorLabel.text = kNotEnoughColorsDefined
        errorLabel.hidden = false
        errorLabel.center = errorLabelCenter
        return false
    }
    if segmentsSum == 0 {
        errorLabel.text = kDataZeroError
        errorLabel.hidden = false
        errorLabel.center = errorLabelCenter
        return false
    } else {
        errorLabel.text = ""
        errorLabel.hidden = true
    }
    
    //  Calculate start and end radians for each segment
    segmentGeometricValues.removeAll()
    for (index, segment) in segmentDataArray.enumerate() {
        segmentEndRadian = (segment / segmentsSum) * M_PI_CGFloat + segmentStartRadian
        let pushOutStatus = pushOutSegment(segmentStartRadian, endRadian: segmentEndRadian, currentSegmentIndex: index)
        let segmentGeometryValue = SegmentGeometryStruct(index: index, chartData: segment, startRadian: segmentStartRadian, endRadian: segmentEndRadian, segmentColor: segmentColors[index], pushOut: pushOutStatus)
        segmentGeometricValues.append(segmentGeometryValue)
        segmentStartRadian = segmentEndRadian
    }
    return true
  }
    
  override public func drawRect(rect: CGRect) {
    if initializeValues(rect.size) {
      for segmentValue in segmentGeometricValues {
        if segmentValue.chartData > 0 {
          let segColor = (segmentSelected == segmentValue.index) ? segmentValue.segmentColor.darkenColor(kColorDarkenFactor) : segmentValue.segmentColor
          drawSegment(centerPoint, outerCircleMidRad: doughNutMidRadius, startRadian: segmentValue.startRadian, endRadian: segmentValue.endRadian, segmentIndex: segmentValue.index, segmentColor: segColor, outerCircleStrokeWidth: doughNutWidth, segmentData: segmentValue.chartData, pushOutStatus: segmentValue.pushOut)
        }
      }
      //  Draw Center Label
      let centerLabelY = centerPoint.y - centerLabelFontSize / 2
      let centerLabelCenter = CGPoint(x: centerPoint.x, y: centerLabelY)
      let centerLabelData = Int(segmentDataArray.reduce(0.0, combine: { $0 + $1 }))
      if #available(iOS 8.2, *) {
        drawLabel(centerLabelCenter, labelText: String(Int(centerLabelData)), fontSize: centerLabelFontSize, labelWeight: UIFontWeightBold)
      } else {
        drawLabel(centerLabelCenter, labelText: String(Int(centerLabelData)), fontSize: centerLabelFontSize)
      }
    }
  }

  
  private func drawSegment(center: CGPoint, outerCircleMidRad: CGFloat, startRadian: CGFloat, endRadian: CGFloat, segmentIndex: Int, segmentColor: UIColor, outerCircleStrokeWidth: CGFloat, segmentData: CGFloat, pushOutStatus: Bool) {
      
    let innerRingRadius: CGFloat = outerCircleMidRad - outerCircleStrokeWidth / 2 - innerRingWidth / 2
    let segmentSeperatorRadius: CGFloat = outerCircleMidRad - innerRingWidth / 2
    let segmentSeperatorStrokeWidth: CGFloat = outerCircleStrokeWidth + innerRingWidth
    
    let outerCircle = UIBezierPath(arcCenter: center, radius: outerCircleMidRad, startAngle: startRadian, endAngle: endRadian, clockwise: true)
    segmentColor.setStroke()
    outerCircle.lineWidth = outerCircleStrokeWidth
    outerCircle.stroke()
    
    let innerRing = UIBezierPath(arcCenter: center, radius: innerRingRadius, startAngle: startRadian, endAngle: endRadian, clockwise: true)
    segmentColor.lightenColor(kColorDarkenFactor).setStroke()
    innerRing.lineWidth = innerRingWidth
    innerRing.stroke()
    
    //  Do not draw segment seperator if index == 0
    if segmentIndex != 0 {
      let segmentSeperator = UIBezierPath(arcCenter: center, radius: segmentSeperatorRadius, startAngle: startRadian, endAngle: (startRadian + segmentSeperatorGap), clockwise: true)
      UIColor.whiteColor().setStroke()
      segmentSeperator.lineWidth = segmentSeperatorStrokeWidth
      segmentSeperator.stroke()
    }
    
    //  derive centerpoints for segment labels
    let centerRadian = (startRadian + endRadian) / 2
    let pushOutMarginX: CGFloat = 0.0
    let pushOutMarginY: CGFloat = 0.0
    if pushOutStatus {
//      pushOutMarginX =  pushOutLabelMargin * cos(centerRadian) //Used to push out the labels. This is not used now.
//      pushOutMarginY =  pushOutLabelMargin * sin(centerRadian) //Used to push out the labels. This is not used now.
    }
    let centerX = (cos(centerRadian) * (doughNutOuterRadius + labelMargin / 2)) + centerPoint.x + pushOutMarginX
    let centerY = (sin(centerRadian) * (doughNutOuterRadius + labelMargin / 2 )) + centerPoint.y + pushOutMarginY
    let labelCenter = CGPoint(x: centerX, y: centerY)
    if !pushOutStatus {
      if #available(iOS 8.2, *) {
        drawLabel(labelCenter, labelText: String(Int(segmentData)), fontSize: labelFontSize, labelWeight: UIFontWeightRegular)
      } else {
        drawLabel(labelCenter, labelText: String(Int(segmentData)), fontSize: labelFontSize)
      }
    }
  }
  
  private func drawLabel(labelCenter: CGPoint, labelText: String, fontSize: CGFloat, labelWeight: CGFloat? = nil) {
    var labelFont = UIFont()
    if let labelWeight = labelWeight {
      if #available(iOS 8.2, *) {
        labelFont = UIFont.systemFontOfSize(fontSize, weight: labelWeight)
      } else {
        labelFont = UIFont.systemFontOfSize(fontSize)
          
      }
    } else {
      labelFont = UIFont.systemFontOfSize(fontSize)
    }
    let labelNSString = labelText as NSString
    let labelWidth = labelNSString.sizeWithAttributes([NSFontAttributeName: labelFont])
    let labelFrame = CGRectMake(0.0, 0.0, labelWidth.width, labelFontSize)
    let labelSegment = UILabel(frame: labelFrame)
    segmentLabelQueue.append(labelSegment)
    labelSegment.center = labelCenter
    labelSegment.text = labelText
    labelSegment.textColor = labelFontColor
    labelSegment.font = labelFont
    self.addSubview(labelSegment)
  }
  
  
  func viewTapped(tapRecognizer: UITapGestureRecognizer) {
    let tappedPoint = tapRecognizer.locationInView(self)
    segmentSelected = segmentTapped(tappedPoint)
    self.setNeedsDisplay() //Darkens tapped segement. Taps outside segment will clear darkened color
    self.delegate?.chartSegmentClicked(self, segmentClicked: segmentSelected)
  }
  
  
  // Returns segment tapped. If tapped outside the segment it will return -1
  private func segmentTapped (tappedPoint: CGPoint) -> Int {
    var tappedSegment = SegmentGeometryStruct()
    tappedSegment.index = -1
    let hypot = hypotBetweenPoints(centerPoint, endPoint: tappedPoint)
    if ((hypot < doughNutOuterRadius) && (hypot > (doughNutOuterRadius - doughNutWidth))) {
      let touchPointInRadians = touchPointRadians(centerPoint, endingPoint: tappedPoint)
      for segmentGeometryValue in segmentGeometricValues {
        if (touchPointInRadians >= segmentGeometryValue.startRadian && touchPointInRadians <= segmentGeometryValue.endRadian) {
            tappedSegment = segmentGeometryValue
            break
        }
      }
    }
    return tappedSegment.index
  }


  // This is added to darken the segment when touched/tapped
  override public func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
    if let touch = touches.first {
      let touchPoint = touch.locationInView(self)
      segmentSelected = segmentTapped(touchPoint)
      self.setNeedsDisplay() // Darkens the segment color if segment is selected
    }
  }
  
  private func hypotBetweenPoints(startPoint: CGPoint, endPoint: CGPoint) -> CGFloat {
    let deltaX = startPoint.x - endPoint.x
    let deltaY = startPoint.y - endPoint.y
    let hypot: CGFloat = sqrt(deltaX * deltaX + deltaY * deltaY)
    return hypot
  }
  
  
  //This uses atan2f API to determine the angle from the point of touch to the view center point.
  private func touchPointRadians(startingPoint: CGPoint, endingPoint: CGPoint) -> CGFloat  {
    let endPointFromCenter: CGPoint = CGPointMake(endingPoint.x - startingPoint.x, endingPoint.y - startingPoint.y)
    let angleInRadiansInNegative: Float = atan2f(Float(endPointFromCenter.y), Float(endPointFromCenter.x))
    let angleInDegreesInNegative: CGFloat = CGFloat(angleInRadiansInNegative) * (180.0 / M_PI_CGFloat)
    //To get 0 to 360 degrees do the below adjustment
    let angleInDegrees360 = (angleInDegreesInNegative > 0.0 ? angleInDegreesInNegative : (360.0 + angleInDegreesInNegative))
    let angleInRadians360: CGFloat = M_PI_CGFloat / 180.0 * angleInDegrees360
    return angleInRadians360
  }
  
  
//  Push out label functions. Label height is used to determine the min radian needed to display the label.
  private func minRadiansForLabels(labelHeight: CGFloat) -> CGFloat {
    let hypot = doughNutOuterRadius + (labelMargin / 2)
    return asin(labelHeight / hypot)
  }
  
  private func pushOutSegment(startRad: CGFloat, endRadian: CGFloat, currentSegmentIndex: Int) -> Bool {
    if currentSegmentIndex > 0 { // Not first segment
      if segmentGeometricValues[currentSegmentIndex - 1].pushOut { // check if previous segment has been pushed out. If so, do not push current segment
        return false
      } else if ((endRadian - startRad) <  minRadiansNeededForLabels) {
        return true
      } else {
        return false
      }
    } else { // first segment
      return false
    }
  }
  
  public func clearSelection() {
    segmentSelected = -1
    self.setNeedsDisplay()
  }
  
  
  

}
