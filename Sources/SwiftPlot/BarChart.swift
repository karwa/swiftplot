import Foundation

fileprivate let MAX_DIV: Float = 50

// class defining a barGraph and all it's logic
public struct BarGraph<SeriesType> where SeriesType: Sequence {
  public typealias Element = SeriesType.Element

    public var layout = GraphLayout()
    // Data.
    var seriesData: SeriesType
    var adapter: StrideableAdapter<Element>
  
    var stackData = [SeriesType]()
    var barLabels = [String]()
  
    var series_info = Series<String,Int>()
    var stackSeries_info = [Series<String,Int>]()
  
    // BarGraph layout properties.
    public enum GraphOrientation {
        case vertical
        case horizontal
    }
    public var graphOrientation: GraphOrientation = .vertical
    public var minimumSeparation: Int = 20
  
  var originElement: Element
  
  public init(_ data: SeriesType, adapter: StrideableAdapter<Element>, origin: Element) {
    self.seriesData = data
    self.adapter = adapter
    self.originElement = origin
  }
}

extension SequencePlots {
  
  public func barChart(adapter: StrideableAdapter<Base.Element>, origin: Base.Element) -> BarGraph<Base> {
    return BarGraph(base, adapter: adapter, origin: origin)
  }
}

extension SequencePlots where Base.Element: Strideable, Base.Element.Stride: FloatConvertible {
  public func barChart(origin: Base.Element) -> BarGraph<Base> {
    return BarGraph(base, adapter: .linear, origin: origin)
  }
}

extension SequencePlots where Base.Element: Strideable, Base.Element.Stride: FixedWidthInteger {
  public func barChart(origin: Base.Element) -> BarGraph<Base> {
    return BarGraph(base, adapter: .linear, origin: origin)
  }
}

extension BarGraph {
  
  public init(enableGrid: Bool = false){
    fatalError()
    self.enableGrid = enableGrid
  }
}

// Setting data.

extension BarGraph {

    public mutating func addSeries(_ s: SeriesType) {
        seriesData = s
    }
    
    public mutating func addStackSeries(_ s: SeriesType) {
// TODO: Re-enable in layout.
//        precondition(series.count != 0 && series.count == s.count,
//                     "Stack point count does not match the Series point count.")
        stackData.append(s)
        stackSeries_info.append(Series())
    }
    public mutating func addStackSeries(_ x: SeriesType,
                               label: String,
                               color: Color = .lightBlue,
                               hatchPattern: BarGraphSeriesOptions.Hatching = .none) {
      stackData.append(x)
      stackSeries_info.append(Series(values: [],
                                     label: label,
                                     color: color,
                                     hatchPattern: hatchPattern))
    }
    public mutating func addSeries(values: SeriesType,
                          label: String,
                          color: Color = Color.lightBlue,
                          hatchPattern: BarGraphSeriesOptions.Hatching = .none,
                          graphOrientation: BarGraph.GraphOrientation = .vertical){
      seriesData = values
      series_info = Series(values: [],
                           label: label,
                           color: color,
                           hatchPattern: hatchPattern)
      self.graphOrientation = graphOrientation
    }
//    public mutating func addSeries(_ x: [String],
//                          _ y: [U],
//                          label: String,
//                          color: Color = Color.lightBlue,
//                          hatchPattern: BarGraphSeriesOptions.Hatching = .none,
//                          graphOrientation: BarGraph.GraphOrientation = .vertical){
//        self.addSeries(values: zip(x, y).map { Pair($0.0, $0.1) },
//                       label: label, color: color, hatchPattern: hatchPattern,
//                       graphOrientation: graphOrientation)
//    }
}

// Layout properties.

extension BarGraph {
    
    public var enableGrid: Bool {
        get { layout.enablePrimaryAxisGrid }
        set { layout.enablePrimaryAxisGrid = newValue }
    }
}

// Layout and drawing of data.

extension BarGraph: HasGraphLayout & Plot {
    
    public var legendLabels: [(String, LegendIcon)] {
        var legendSeries = stackSeries_info.map { ($0.label, LegendIcon.square($0.color)) }
        legendSeries.insert((series_info.label, .square(series_info.color)), at: 0)
        return legendSeries
    }
    
    public typealias DrawingData = BarGraphLayoutData
  
    // functions implementing plotting logic
    public func _layoutData(size: Size, renderer: Renderer, getStackHeight: ()->Float?) -> (DrawingData, PlotMarkers?) {
        
        var results = DrawingData()
        var markers = PlotMarkers()
      
        switch graphOrientation {
        case .vertical:
          
          // - Find the maximum/minimum elements.
          var maxBarHeight: Float = 0
          var minBarHeight: Float = 0
          var count = 0
          for element in seriesData {
            count += 1
            var thisBarHeight = adapter.distance(from: originElement, to: element)
            thisBarHeight    += getStackHeight() ?? 0
            maxBarHeight = max(maxBarHeight, thisBarHeight)
            minBarHeight = min(minBarHeight, thisBarHeight)
          }
          while let extraStackHeight = getStackHeight() {
            count += 1
            maxBarHeight = max(maxBarHeight, extraStackHeight)
            minBarHeight = min(minBarHeight, extraStackHeight)
          }
          if Float(count) > size.width {
            print("⚠️ - Graph is too small. Less than 1 pixel per bar.")
          }
          
          // - Calculate margins, origin, scale, etc.
          var hasTopMargin = true
          var hasBottomMargin = true
          if maxBarHeight < 0 {
            // maxElement < origin. All bars are below the origin.
            maxBarHeight = 0
            results.origin = Point(0, size.height)
            hasTopMargin = false
            // FIXME: plot markers on top?
          }
          if minBarHeight >= 0 {
            // minElement >= origin. All bars are above the origin.
            minBarHeight = 0
            results.origin = zeroPoint
            hasBottomMargin = false
          }
          
          let yMarginSize = size.height * 0.1
          let dataHeight  = size.height - (hasTopMargin ? yMarginSize : 0)
                                        - (hasBottomMargin ? yMarginSize : 0)
          
          results.scaleY = dataHeight / (maxBarHeight - minBarHeight)
          
          results.origin.y = abs(minBarHeight * results.scaleY)
                             + (hasBottomMargin ? yMarginSize : 0)
          results.origin.y.round()
          
          // Round the bar width to an integer size.
          let totalSeparation = Float((count + 1) * minimumSeparation)
          let spaceForBars    = size.width - totalSeparation
          results.barWidth = Int((spaceForBars / Float(count)).rounded(.down))
          results.barWidth = max(results.barWidth, 1)
          // The rounding may have introduced a large space at the end.
          // e.g. 800 bars in 900 pixels gives 1 pixel/bar and 100 pixels space!
          // Distribute the space as additional separation.
          // Even though this un-integers the bar locations, it results in overall better charts.
          results.space = (size.width - Float(count * results.barWidth)) / Float(count + 1)
          // Requiring 1 pixel per bar means we can't always honour the minimum separation.
          if results.space < Float(minimumSeparation) {
            print("⚠️ - Not enough space to honour minimum separation. " +
                  "Bars would be less than 1 pixel.")
          }
          
          // - Calculate Y marker locations.
          let nD1: Int = max(getNumberOfDigits(maxBarHeight), getNumberOfDigits(minBarHeight))
          var v1: Float
          if nD1 > 1 && maxBarHeight <= pow(Float(10), Float(nD1 - 1)) {
            v1 = Float(pow(Float(10), Float(nD1 - 2)))
          } else if (nD1 > 1) {
            v1 = Float(pow(Float(10), Float(nD1 - 1)))
          } else {
            v1 = Float(pow(Float(10), Float(0)))
          }
          
          let nY: Float = v1*results.scaleY
          var inc1: Float = nY
          if(size.height/nY > MAX_DIV){
            inc1 = (size.height/nY)*inc1/MAX_DIV
          }
          
          var yM = results.origin.y
          while yM <= size.height {
            if yM + inc1 < 0 || yM < 0 {
              yM = yM + inc1
              continue
            }
            markers.yMarkers.append(yM)
            let text = "\(( (yM - results.origin.y) / results.scaleY ).rounded())"
            markers.yMarkersText.append(text)
            yM = yM + inc1
          }
          yM = results.origin.y - inc1
          while yM>0.0 {
            markers.yMarkers.append(yM)
            markers.yMarkersText.append("\(round((yM-results.origin.y)/results.scaleY))")
            yM = yM - inc1
          }
          
          // - Calculate X marker locations.
          // TODO: Do not show all x-markers if there are too many bars.
          // TODO: Allow setting x-markers.
          var i = 0
          for value in seriesData {
            markers.xMarkers.append(results.xMarkerLocationForBar(i))
            markers.xMarkersText.append(String(describing: value))
            i += 1
          }
          for _ in i..<count {
            markers.xMarkers.append(results.xMarkerLocationForBar(i))
            markers.xMarkersText.append("")
            i += 1
          }
          
        case .horizontal:
          break
//          results.barWidth = Int(round(size.height/Float(series.count)))
//          maximumX = maxY(points: series.values)
//          minimumX = minY(points: series.values)
//
//          var maximumX: U = U(0)
//          var minimumX: U = U(0)
//
//            var x = maxY(points: series.values)
//            if (x > maximumX) {
//                maximumX = x
//            }
//            x = minY(points: series.values)
//            if (x < minimumX) {
//                minimumX = x
//            }
//
//            for s in stackSeries {
//                let minStackX = minY(points: s.values)
//                let maxStackX = maxY(points: s.values)
//                maximumX = maximumX + maxStackX
//                minimumX = minimumX - minStackX
//            }
//
//            if minimumX >= U(0) {
//                results.origin = zeroPoint
//                minimumX = U(0)
//            }
//            else{
//                results.origin = Point((size.width/Float(maximumX-minimumX))*Float(U(-1)*minimumX), 0.0)
//            }
//
//            let rightScaleMargin: Float = size.width * 0.1
//            results.scaleX = Float(maximumX - minimumX) / (size.width - rightScaleMargin)
//
//            let nD1: Int = max(getNumberOfDigits(Float(maximumX)), getNumberOfDigits(Float(minimumX)))
//            var v1: Float
//            if (nD1 > 1 && maximumX <= U(pow(Float(10), Float(nD1 - 1)))) {
//                v1 = Float(pow(Float(10), Float(nD1 - 2)))
//            } else if (nD1 > 1) {
//                v1 = Float(pow(Float(10), Float(nD1 - 1)))
//            } else {
//                v1 = Float(pow(Float(10), Float(0)))
//            }
//
//            let nX: Float = v1/results.scaleX
//            var inc1: Float = nX
//            if(size.width/nX > MAX_DIV){
//                inc1 = (size.width/nX)*inc1/MAX_DIV
//            }
//
//            var xM = results.origin.x
//            while xM<=size.width {
//                if(xM+inc1<0.0 || xM<0.0){
//                    xM = xM + inc1
//                    continue
//                }
//                markers.xMarkers.append(xM)
//                markers.xMarkersText.append("\(ceil(results.scaleX*(xM-results.origin.x)))")
//                xM = xM + inc1
//            }
//            xM = results.origin.x - inc1
//            while xM>0.0 {
//                markers.xMarkers.append(xM)
//                markers.xMarkersText.append("\(floor(results.scaleX*(xM-results.origin.x)))")
//                xM = xM - inc1
//            }
//
//            func yMarkerLocationForBar(_ index: Int) -> Float {
//                Float(index*results.barWidth) + Float(results.barWidth)*Float(0.5)
//            }
//            func yLocationForBar(_ index: Int) -> Float {
//                yMarkerLocationForBar(index) - Float(results.barWidth)*Float(0.5) + Float(space)*Float(0.5)
//            }
//            for i in 0..<series.count {
//                markers.yMarkers.append(yMarkerLocationForBar(i))
//                markers.yMarkersText.append("\(series[i].x)")
//            }
//
//            // scale points to be plotted according to plot size
//            let scaleXInv: Float = 1.0/results.scaleX
//            results.series_scaledValues = (0..<series.values.count).map { i in
//                let pt = series.values[i]
//                return Pair(Float(pt.y*U(scaleXInv)+U(results.origin.x)), yLocationForBar(i))
//            }
//            results.stackSeries_scaledValues = stackSeries.map { series in
//                (0..<series.values.count).map { i in
//                    let pt = series.values[i]
//                    return Pair(Float(pt.y*U(scaleXInv)+U(results.origin.x)), yLocationForBar(i))
//                }
//            }
        }
        return (results, markers)
    }

    //functions to draw the plot
  public func _drawData(_ data: DrawingData, size: Size, renderer: Renderer, drawStack: (inout BarLayoutData)->Bool) {
    switch graphOrientation {
    case .vertical:
      var barIndex = 0
      for seriesValue in seriesData {
        // Draw the bar from the main series.
        let seriesHeight = (adapter.distance(from: originElement, to: seriesValue) * data.scaleY).rounded(.up)
        let rect = Rect(origin: Point(data.xLocationForBar(barIndex), data.origin.y),
                        size: Size(width: Float(data.barWidth), height: seriesHeight))
        renderer.drawSolidRect(rect,
                               fillColor: series_info.color,
                               hatchPattern: series_info.barGraphSeriesOptions.hatchPattern)
        // Call up the stack chain to draw their segments.
        var barLayoutData = BarLayoutData(layout: data, xLocation: rect.minX,
                                          positiveValueHeight: rect.height > 0 ? rect.height : 0,
                                          negativeValueHeight: rect.height < 0 ? -1 * rect.height : 0)
        _ = drawStack(&barLayoutData)
        barIndex += 1
      }
      // Consume any remaining bars from the stack chain.
      var barLayoutData = BarLayoutData(layout: data, xLocation: data.xLocationForBar(barIndex),
                                        positiveValueHeight: 0, negativeValueHeight: 0)
      while drawStack(&barLayoutData) {
        barIndex += 1
        barLayoutData = BarLayoutData(layout: data, xLocation: data.xLocationForBar(barIndex),
                                      positiveValueHeight: 0, negativeValueHeight: 0)
      }
          
        case .horizontal:
          break
//            for index in 0..<series.count {
//                var currentWidthPositive: Float = 0
//                var currentWidthNegative: Float = 0
//                var rect = Rect(
//                    origin: Point(data.origin.x, data.series_scaledValues[index].y),
//                    size: Size(
//                        width: data.series_scaledValues[index].x - data.origin.x,
//                        height: Float(data.barWidth - space))
//                )
//                if (rect.size.width >= 0) {
//                    currentWidthPositive = rect.size.width
//                }
//                else {
//                    currentWidthNegative = rect.size.width
//                }
//                renderer.drawSolidRect(rect,
//                                       fillColor: series.color,
//                                       hatchPattern: series.barGraphSeriesOptions.hatchPattern)
//                for i in 0..<stackSeries.count {
//                    let stackValue = Float(data.stackSeries_scaledValues[i][index].x)
//                    if (stackValue - data.origin.x >= 0) {
//                        rect.origin.x = data.origin.x + currentWidthPositive
//                        rect.size.width = stackValue - data.origin.x
//                        currentWidthPositive += stackValue
//                    }
//                    else {
//                        rect.origin.x = data.origin.x - currentWidthNegative - stackValue
//                        rect.size.width = stackValue - data.origin.x
//                        currentWidthNegative += stackValue
//                    }
//                    renderer.drawSolidRect(rect,
//                                           fillColor: stackSeries[i].color,
//                                           hatchPattern: stackSeries[i].barGraphSeriesOptions.hatchPattern)
//                }
//            }
        }
    }
}

public struct StrideableAdapter<T> {
  var distanceFromTo: (T, T) -> Float
  var compare: (T, T) -> Bool
  
  public init(compare areInIncreasingOrder: Optional<(T, T) -> Bool> = nil,
              distanceFromTo: @escaping (T, T) -> Float) {
    self.distanceFromTo = distanceFromTo
    self.compare = areInIncreasingOrder ?? { distanceFromTo($0, $1) > 0 }
  }
  
  public func distance(from: T, to: T) -> Float { return distanceFromTo(from, to) }
}

// Default adapters for numeric types.

extension StrideableAdapter where T: Strideable, T.Stride: FloatConvertible {
  public static var linear: StrideableAdapter {
    return StrideableAdapter(
      compare: <,
      distanceFromTo: { Float($0.distance(to: $1)) }
    )
  }
}
extension StrideableAdapter where T: Strideable, T.Stride: FixedWidthInteger {
  public static var linear: StrideableAdapter {
    return StrideableAdapter(
      compare: <,
      distanceFromTo: { Float($0.distance(to: $1)) }
    )
  }
}

// Keypath numeric adapters.

extension StrideableAdapter {
  public static func keyPath<Element>(_ kp: KeyPath<T, Element>) -> StrideableAdapter
    where Element: Strideable, Element.Stride: FloatConvertible {
    return StrideableAdapter(
      compare: { $0[keyPath: kp] < $1[keyPath: kp] },
      distanceFromTo: { Float($0[keyPath: kp].distance(to: $1[keyPath: kp])) }
    )
  }
  public static func keyPath<Element>(_ kp: KeyPath<T, Element>) -> StrideableAdapter
    where Element: Strideable, Element.Stride: FixedWidthInteger {
    return StrideableAdapter(
      compare: { $0[keyPath: kp] < $1[keyPath: kp] },
      distanceFromTo: { Float($0[keyPath: kp].distance(to: $1[keyPath: kp])) }
    )
  }
}

// Note: This cannot be nested in the BarGraph because we
// need it to be non-generic for stacking.
public struct BarGraphLayoutData {
    var scaleY: Float = 1
    var scaleX: Float = 1
    var barWidth : Int = 0
    var origin = zeroPoint
    var space: Float = 0
  
    func xLocationForBar(_ index: Int) -> Float {
        Float(index * barWidth)     // bar widths.
        + Float(index + 1) * space  // spacing.
    }
    func xMarkerLocationForBar(_ index: Int) -> Float {
        xLocationForBar(index)
        + Float(barWidth) * 0.5  // center on bar.
    }
}

// Stacking prototype.


public struct BarLayoutData {
  var layout: BarGraphLayoutData
  var xLocation: Float
  var positiveValueHeight: Float
  var negativeValueHeight: Float
}

public protocol BarGraphProtocol: Plot, HasGraphLayout {
  associatedtype Parent: BarGraphProtocol
  var parent: Parent? { get set }
  
  func _layoutData(size: Size, renderer: Renderer, getStackHeight: ()->Float?) -> (DrawingData, PlotMarkers?)
  
  func _drawData(_ data: DrawingData, size: Size, renderer: Renderer,
                 drawStack: (inout BarLayoutData)->Bool)
}

extension BarGraph: BarGraphProtocol {
  public var parent: Self? {
    get { return nil }
    set { fatalError() }
  }
}

extension BarGraphProtocol {
  
  public func layoutData(size: Size, renderer: Renderer) -> (DrawingData, PlotMarkers?) {
    // This gets called when we are at the top of the stack.
    // Delegate to our own chain of layout functions and terminate the closure-chain.
    return _layoutData(size: size, renderer: renderer, getStackHeight: { nil })
  }
  
  public func drawData(_ data: DrawingData, size: Size, renderer: Renderer) {
    // This gets called when we are at the top of the stack.
    // Delegate to our own chain of layout functions and terminate the closure-chain.
    _drawData(data, size: size, renderer: renderer, drawStack: { _ in false })
  }
  
  public func stackedWith<S>(_ stackSeries: S, adapter: StrideableAdapter<S.Element>, origin: S.Element) -> StackedBarGraph<Self, S> where S: Sequence {
    return StackedBarGraph(base: self, values: stackSeries, adapter: adapter, origin: origin)
  }
}



public struct StackedBarGraph<Base, SeriesType> where SeriesType: Sequence, Base: BarGraphProtocol {
  public typealias Element = SeriesType.Element
  
  var base: Base
  public var values: SeriesType
  var adapter: StrideableAdapter<Element>
  var origin: Element
  public var segmentColor: Color = .orange
}

extension StackedBarGraph: Plot & HasGraphLayout {

  public var layout: GraphLayout {
    get { return base.layout }
    set { base.layout = newValue }
  }
  
  public struct DrawingData {
    var baseData: Base.DrawingData!
  }
  
  public func _layoutData(size: Size, renderer: Renderer, getStackHeight: ()->Float?) -> (DrawingData, PlotMarkers?) {
    
    // Calculate maximum/minimum/count, and pass it down to base.
    
    var it = values.makeIterator()
    let baseResults = base._layoutData(size: size, renderer: renderer, getStackHeight: {
      let base = getStackHeight()
      if let nextValue = it.next() {
        return (base ?? 0) + adapter.distance(from: origin, to: nextValue)
      }
      return base
    })
    return (DrawingData(baseData: baseResults.0), baseResults.1)
  }
  
  public func _drawData(_ data: DrawingData, size: Size, renderer: Renderer,
                        drawStack: (inout BarLayoutData)->Bool) {
    
    var it = values.makeIterator()
    base._drawData(data.baseData, size: size, renderer: renderer, drawStack: { layoutInfo in
      var shouldContinue: Bool
      // Draw our stack segment.
      if let nextValue = it.next() {
        let segmentHeight = adapter.distance(from: origin, to: nextValue) * layoutInfo.layout.scaleY
        var segmentRect = Rect(origin: Point(layoutInfo.xLocation,
                                             layoutInfo.layout.origin.y + layoutInfo.positiveValueHeight),
                               size: Size(width: Float(layoutInfo.layout.barWidth), height: segmentHeight))
        if segmentHeight < 0 {
          segmentRect.origin.y = layoutInfo.layout.origin.y - layoutInfo.negativeValueHeight
          layoutInfo.negativeValueHeight += -1 * segmentHeight
        } else {
           layoutInfo.positiveValueHeight += segmentHeight
        }
        renderer.drawSolidRect(segmentRect, fillColor: segmentColor, hatchPattern: .none)
        shouldContinue = true
      } else {
        shouldContinue = false
      }
      // Draw the next segment in the chain.
      let shouldParentContinue = drawStack(&layoutInfo)
      return shouldContinue || shouldParentContinue
    })
  }
}

extension StackedBarGraph: BarGraphProtocol {
  
  public var parent: Base? {
    get { return base }
    set { base = newValue! }
  }
}
