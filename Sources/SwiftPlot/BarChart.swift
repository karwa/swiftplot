import Foundation

fileprivate let MAX_DIV: Float = 50

// class defining a barGraph and all it's logic
public struct BarGraph<SeriesType> where SeriesType: Sequence {
  public typealias Element = SeriesType.Element
  
  public var layout = GraphLayout()
  // Data.
  public var values: SeriesType
  // BarGraph layout properties.
  public var adapter: StrideableAdapter<Element>
  public var formatter: TextFormatter<Element> = .default
  public var originElement: Element
  
  public var graphOrientation = GraphOrientation.vertical
  public var minimumSeparation = 20
  
  public var label = ""
  public var color = Color.orange
  public var hatchPattern = BarGraphSeriesOptions.Hatching.none
  
  public init(_ data: SeriesType, adapter: StrideableAdapter<Element>, origin: Element) {
    self.values = data
    self.adapter = adapter
    self.originElement = origin
  }
}

extension SequencePlots {
  public func barChart(
    adapter: StrideableAdapter<Base.Element>,
    origin: Base.Element,
    style: (inout BarGraph<Base>)->Void = { _ in }) -> BarGraph<Base> {
    var graph = BarGraph(base, adapter: adapter, origin: origin)
    style(&graph)
    return graph
  }
}

// Default adapter for Stride: FloatConvertible.
extension SequencePlots where Base.Element: Strideable, Base.Element.Stride: FloatConvertible {
  public func barChart(
    origin: Base.Element,
    style: (inout BarGraph<Base>)->Void = { _ in }) -> BarGraph<Base> {
    return self.barChart(adapter: .linear, origin: origin, style: style)
  }
}
// Default adapter and origin for Stride: FloatConvertible.
extension SequencePlots where Base.Element: Strideable, Base.Element.Stride: FloatConvertible,
Base.Element: ExpressibleByIntegerLiteral {
  public func barChart(style: (inout BarGraph<Base>)->Void = { _ in }) -> BarGraph<Base> {
    return self.barChart(adapter: .linear, origin: 0, style: style)
  }
}
// Default adapter for Stride: FixedWidthInteger.
extension SequencePlots where Base.Element: Strideable, Base.Element.Stride: FixedWidthInteger {
  public func barChart(
    origin: Base.Element,
    style: (inout BarGraph<Base>)->Void = { _ in }) -> BarGraph<Base> {
    return self.barChart(adapter: .linear, origin: origin, style: style)
  }
}
// Default adapter and origin for Stride: FixedWidthInteger
extension SequencePlots where Base.Element: Strideable, Base.Element.Stride: FixedWidthInteger,
Base.Element: ExpressibleByIntegerLiteral {
  public func barChart(style: (inout BarGraph<Base>)->Void = { _ in }) -> BarGraph<Base> {
    return self.barChart(adapter: .linear, origin: 0, style: style)
  }
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
    
  public func _appendLegendLabel(to: inout [(String, LegendIcon)]) {
    to.append((label, .square(color)))
  }
  
  public typealias DrawingData = BarGraphLayoutData
  
    // functions implementing plotting logic
  public func _layoutData(size: Size, renderer: Renderer, getStackHeight: ()->(Float, Float)?) -> (DrawingData, PlotMarkers?) {
        
      var results = DrawingData()
      results.orientation = graphOrientation
      var markers = PlotMarkers()
      
      // - Find the maximum/minimum elements.
      var maxBarHeight: Float = 0
      var minBarHeight: Float = 0
      var count = 0
      for element in values {
        count += 1
        var barHeight: (Float, Float) = (0, 0)
        let seriesHeight = adapter.distance(from: originElement, to: element)
        if seriesHeight > 0 {
          barHeight.0 = seriesHeight
        } else {
          barHeight.1 = -1 * seriesHeight * -1
        }
        getStackHeight().map {
          barHeight.0 += $0.0
          barHeight.1 += -1 * $0.1 * -1
        }
        
        maxBarHeight = max(maxBarHeight, barHeight.0)
        maxBarHeight = max(maxBarHeight, barHeight.1)
        minBarHeight = min(minBarHeight, barHeight.0)
        minBarHeight = min(minBarHeight, barHeight.1)
      }
      while let extraStackHeight = getStackHeight() {
        count += 1
        maxBarHeight = max(maxBarHeight, extraStackHeight.0)
        maxBarHeight = max(maxBarHeight, extraStackHeight.1)
        minBarHeight = min(minBarHeight, extraStackHeight.0)
        minBarHeight = min(minBarHeight, extraStackHeight.1)
      }
      if Float(count) > size.width {
        print("⚠️ - Graph is too small. Less than 1 pixel per bar.")
      }
      guard count > 0 else { return (results, markers) }
      
      switch graphOrientation {
      case .vertical:
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
          
          results.scale = dataHeight / (maxBarHeight - minBarHeight)
          
          results.origin.y = abs(minBarHeight * results.scale)
                             + (hasBottomMargin ? yMarginSize : 0)
          results.origin.y.round()
          
          // Round the bar width to an integer size.
          let totalSeparation = Float((count + 1) * minimumSeparation)
          let spaceForBars    = size.width - totalSeparation
          results.barSize = Int((spaceForBars / Float(count)).rounded(.down))
          results.barSize = max(results.barSize, 1)
          // The rounding may have introduced a large space at the end.
          // e.g. 800 bars in 900 pixels gives 1 pixel/bar and 100 pixels space!
          // Distribute the space as additional separation.
          // Even though this un-integers the bar locations, it results in overall better charts.
          results.space = (size.width - Float(count * results.barSize)) / Float(count + 1)
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
          
          let nY: Float = v1*results.scale
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
            let text = "\( ((yM - results.origin.y) / results.scale ).rounded() )"
            markers.yMarkersText.append(text)
            yM = yM + inc1
          }
          yM = results.origin.y - inc1
          while yM>0.0 {
            markers.yMarkers.append(yM)
            markers.yMarkersText.append("\( ((yM - results.origin.y) / results.scale ).rounded() )")
            yM = yM - inc1
          }
          
          // - Calculate X marker locations.
          // TODO: Do not show all x-markers if there are too many bars.
          // TODO: Allow setting x-markers.
          var i = 0
          for value in values {
            markers.xMarkers.append(results.axisMarkerLocationForBar(i))
            markers.xMarkersText.append(formatter.callAsFunction(value, offset: i))
            i += 1
          }
          for _ in i..<count {
            markers.xMarkers.append(results.axisMarkerLocationForBar(i))
            markers.xMarkersText.append("")
            i += 1
          }
          
        case .horizontal:
          // - Calculate margins, origin, scale, etc.
          var hasLeftMargin = true
          var hasRightMargin = true
          if maxBarHeight < 0 {
            // maxElement < origin. All bars are below the origin.
            maxBarHeight = 0
            results.origin = Point(size.width, 0)
            hasLeftMargin = false
            // FIXME: plot markers on top?
          }
          if minBarHeight >= 0 {
            // minElement >= origin. All bars are above the origin.
            minBarHeight = 0
            results.origin = zeroPoint
            hasRightMargin = false
          }
          
          let xMarginSize = size.width * 0.1
          let dataWidth  = size.width - (hasLeftMargin ? xMarginSize : 0)
                                      - (hasRightMargin ? xMarginSize : 0)
          
          results.scale = dataWidth / (maxBarHeight - minBarHeight)
          
          results.origin.x = abs(minBarHeight * results.scale)
                             + (hasLeftMargin ? xMarginSize : 0)
          results.origin.x.round()
          
          // Round the bar width to an integer size.
          let totalSeparation = Float((count + 1) * minimumSeparation)
          let spaceForBars    = size.height - totalSeparation
          results.barSize = Int((spaceForBars / Float(count)).rounded(.down))
          results.barSize = max(results.barSize, 1)
          // The rounding may have introduced a large space at the end.
          // e.g. 800 bars in 900 pixels gives 1 pixel/bar and 100 pixels space!
          // Distribute the space as additional separation.
          // Even though this un-integers the bar locations, it results in overall better charts.
          results.space = (size.height - Float(count * results.barSize)) / Float(count + 1)
          // Requiring 1 pixel per bar means we can't always honour the minimum separation.
          if results.space < Float(minimumSeparation) {
            print("⚠️ - Not enough space to honour minimum separation. " +
                  "Bars would be less than 1 pixel.")
          }

          let nD1: Int = max(getNumberOfDigits(Float(maxBarHeight)), getNumberOfDigits(Float(minBarHeight)))
          var v1: Float
          if nD1 > 1 && maxBarHeight <= pow(Float(10), Float(nD1 - 1)) {
            v1 = Float(pow(Float(10), Float(nD1 - 2)))
          } else if (nD1 > 1) {
            v1 = Float(pow(Float(10), Float(nD1 - 1)))
          } else {
            v1 = Float(pow(Float(10), Float(0)))
          }
          
          let nX: Float = v1 * results.scale
          var inc1: Float = nX
          if(size.width/nX > MAX_DIV){
            inc1 = (size.width/nX)*inc1/MAX_DIV
          }
          
          var xM = results.origin.x
          while xM<=size.width {
            if(xM+inc1<0.0 || xM<0.0){
              xM = xM + inc1
              continue
            }
            markers.xMarkers.append(xM)
            markers.xMarkersText.append("\( ((xM - results.origin.x) / results.scale).rounded() )")
            xM = xM + inc1
          }
          xM = results.origin.x - inc1
          while xM>0.0 {
            markers.xMarkers.append(xM)
            markers.xMarkersText.append("\( ((xM - results.origin.x) / results.scale).rounded() )")
            xM = xM - inc1
          }

        // - Calculate Y marker locations.
        // TODO: Do not show all y-markers if there are too many bars.
        // TODO: Allow setting y-markers.
        var i = 0
        for value in values {
          markers.yMarkers.append(results.axisMarkerLocationForBar(i))
          markers.yMarkersText.append(formatter.callAsFunction(value, offset: i))
          i += 1
        }
        for _ in i..<count {
          markers.yMarkers.append(results.axisMarkerLocationForBar(i))
          markers.yMarkersText.append("")
          i += 1
        }
      }
      return (results, markers)
  }
  
  //functions to draw the plot
  public func _drawData(_ data: DrawingData, size: Size, renderer: Renderer, drawStack: (inout BarLayoutData)->Bool) {
    switch graphOrientation {
    case .vertical:
      var barIndex = 0
      for seriesValue in values {
        // Draw the bar from the main series.
        let seriesHeight = (adapter.distance(from: originElement, to: seriesValue) * data.scale).rounded(.up)
        let rect = Rect(origin: Point(data.axisLocationForBar(barIndex), data.origin.y),
                        size: Size(width: Float(data.barSize), height: seriesHeight))
        renderer.drawSolidRect(rect, fillColor: color, hatchPattern: hatchPattern)
        // Call up the stack chain to draw their segments.
        var barLayoutData = BarLayoutData(layout: data, axisLocation: rect.minX,
                                          positiveValueHeight: rect.height > 0 ? rect.height : 0,
                                          negativeValueHeight: rect.height < 0 ? -1 * rect.height : 0)
        _ = drawStack(&barLayoutData)
        barIndex += 1
      }
      // Consume any remaining bars from the stack chain.
      var barLayoutData = BarLayoutData(layout: data, axisLocation: data.axisLocationForBar(barIndex),
                                        positiveValueHeight: 0, negativeValueHeight: 0)
      while drawStack(&barLayoutData) {
        barIndex += 1
        barLayoutData = BarLayoutData(layout: data, axisLocation: data.axisLocationForBar(barIndex),
                                      positiveValueHeight: 0, negativeValueHeight: 0)
      }
          
    case .horizontal:
      var barIndex = 0
      for seriesValue in values {
        // Draw the bar from the main series.
        let seriesWidth = (adapter.distance(from: originElement, to: seriesValue) * data.scale).rounded(.up)
        let rect = Rect(origin: Point(data.origin.x, data.axisLocationForBar(barIndex)),
                        size: Size(width: seriesWidth, height: Float(data.barSize)))
        renderer.drawSolidRect(rect, fillColor: color, hatchPattern: hatchPattern)
        // Call up the stack chain to draw their segments.
        var barLayoutData = BarLayoutData(layout: data, axisLocation: rect.minY,
                                          positiveValueHeight: rect.width > 0 ? rect.width : 0,
                                          negativeValueHeight: rect.width < 0 ? -1 * rect.width : 0)
        _ = drawStack(&barLayoutData)
        barIndex += 1
      }
      // Consume any remaining bars from the stack chain.
      var barLayoutData = BarLayoutData(layout: data, axisLocation: data.axisLocationForBar(barIndex),
                                        positiveValueHeight: 0, negativeValueHeight: 0)
      while drawStack(&barLayoutData) {
        barIndex += 1
        barLayoutData = BarLayoutData(layout: data, axisLocation: data.axisLocationForBar(barIndex),
                                      positiveValueHeight: 0, negativeValueHeight: 0)
      }
    }
  }
}

public struct TextFormatter<T> {
  private let _format: (T, Int) -> String
  private init(custom: @escaping (T, Int)->String) {
    self._format = custom
  }
  
  public func callAsFunction(_ val: T, offset: Int) -> String {
    _format(val, offset)
  }
  public static var `default`: TextFormatter<T> {
    return TextFormatter { val, idx in String(describing: val) }
  }
  public static func custom(_ formatter: @escaping (T, Int)->String) -> TextFormatter<T> {
    return TextFormatter(custom: formatter)
  }
  public static func array(_ array: [String]) -> TextFormatter<T> {
    return TextFormatter { [array] _, idx in
      guard array.indices.contains(idx) else { return "" }
      return array[idx]
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

// Note: These cannot be nested in the BarGraph because we
// need them to be non-generic for stacking.
public enum GraphOrientation {
    case vertical
    case horizontal
}

public struct BarGraphLayoutData {
  var scale: Float = 1
  var orientation = GraphOrientation.vertical
  var barSize = 0
  var origin = zeroPoint
  var space: Float = 0
  
  func axisLocationForBar(_ index: Int) -> Float {
    Float(index * barSize)     // bar widths.
      + Float(index + 1) * space  // spacing.
  }
  func axisMarkerLocationForBar(_ index: Int) -> Float {
    axisLocationForBar(index)
      + Float(barSize) * 0.5  // center on bar.
  }
}

// Stacking prototype.


public struct BarLayoutData {
  var layout: BarGraphLayoutData
  var axisLocation: Float
  var positiveValueHeight: Float
  var negativeValueHeight: Float
}

public protocol _BarGraphProtocol: Plot, HasGraphLayout {
  associatedtype Parent: _BarGraphProtocol
  
  /// The stack or series below this element of the `BarGraph`.
  /// The root `BarGraph` is its own parent, so this chain never terminates.
  var parent: Parent { get set }
  
  // Appends legend information for this segment to the given array.
  func _appendLegendLabel(to: inout [(String, LegendIcon)])
  
  // Lays out the bar from this segment down.
  // `getStackHeight` returns a tuple of (positiveSegmentHeight, negativeSegmentHeight).
  func _layoutData(size: Size, renderer: Renderer, getStackHeight: ()->(Float, Float)?) -> (DrawingData, PlotMarkers?)
  
  // Draws the bar from this segment down.
  // Update the `BarLayoutData` to let successive segments know the positive/negative bar height.
  func _drawData(_ data: DrawingData, size: Size, renderer: Renderer,
                 drawStack: (inout BarLayoutData)->Bool)
 
  // A magic associated type which gets funnelled down the chain of generic wrappers,
  // finally terminating at the root `BarGraph`
  associatedtype _RootBarGraphSeriesType: Sequence
  
  /// The `BarGraph`.
  var barGraph: BarGraph<_RootBarGraphSeriesType> { get set }
  
  associatedtype Element
  var originElement: Element { get set }
  var adapter: StrideableAdapter<Element> { get set }
}

extension BarGraph: _BarGraphProtocol {
  public typealias Parent = Self
  public typealias _RootBarGraphSeriesType = SeriesType
  
  public var parent: Self {
    get { return self }
    _modify { yield &self }
    set { self = newValue }
  }
  public var barGraph: BarGraph<SeriesType> {
    get { return self }
    _modify { yield &self }
    set { self = newValue }
  }
}

// Implement HasGraphLayout requirements in terms of our custom versions.

extension _BarGraphProtocol {
  
  public var legendLabels: [(String, LegendIcon)] {
    var labels = [(String, LegendIcon)]()
    _appendLegendLabel(to: &labels)
    labels.reverse()
    return labels
  }
  
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
}

extension _BarGraphProtocol {
  
  public __consuming func style(_ styleBlock: (inout Self)->Void) -> Self {
    var edited = self
    styleBlock(&edited)
    return edited
  }
  
  // Basic initializer.
  
  public func stackedWith<S>(
    _ stackSeries: S,
    adapter: StrideableAdapter<S.Element>,
    origin: S.Element,
    style: (inout StackedBarGraph<Self, S>)->Void = { _ in }) -> StackedBarGraph<Self, S> where S: Sequence {
    var stack = StackedBarGraph(base: self, values: stackSeries, adapter: adapter, originElement: origin)
    style(&stack)
    return stack
  }

  // Default adapter and origin for matching element types.
  
  public func stackedWith<S>(
    _ stackSeries: S,
    style: (inout StackedBarGraph<Self, S>)->Void = { _ in }) -> StackedBarGraph<Self, S>
    where S: Sequence, S.Element == Element {
      return stackedWith(stackSeries, adapter: adapter, origin: originElement, style: style)
  }
  
  // Default adapter for Stride: FloatConvertible.
  
  public func stackedWith<S>(
    _ stackSeries: S,
    origin: S.Element,
    style: (inout StackedBarGraph<Self, S>)->Void = { _ in }) -> StackedBarGraph<Self, S>
    where S: Sequence, S.Element: Strideable, S.Element.Stride: FloatConvertible {
      return stackedWith(stackSeries, adapter: .linear, origin: origin, style: style)
  }
  
  // Default adapter for Stride: FixedWidthInteger.
  
  public func stackedWith<S>(
    _ stackSeries: S,
    origin: S.Element,
    style: (inout StackedBarGraph<Self, S>)->Void = { _ in }) -> StackedBarGraph<Self, S>
    where S: Sequence, S.Element: Strideable, S.Element.Stride: FixedWidthInteger {
      return stackedWith(stackSeries, adapter: .linear, origin: origin, style: style)
  }
}



public struct StackedBarGraph<Base, SeriesType> where SeriesType: Sequence, Base: _BarGraphProtocol {
  public typealias Element = SeriesType.Element
  var base: Base
  public var values: SeriesType
  public var adapter: StrideableAdapter<Element>
  public var originElement: Element
  
  public var segmentLabel = ""
  public var segmentColor = Color.blue
  public var segmentHatchPattern = BarGraphSeriesOptions.Hatching.none
}

extension StackedBarGraph: Plot & HasGraphLayout {

  public var layout: GraphLayout {
    get { return base.layout }
    set { base.layout = newValue }
  }
  
  public struct DrawingData {
    var baseData: Base.DrawingData!
  }
  
  public func _appendLegendLabel(to: inout [(String, LegendIcon)]) {
    to.append((segmentLabel, .square(segmentColor)))
    base._appendLegendLabel(to: &to)
  }

  
  public func _layoutData(size: Size, renderer: Renderer, getStackHeight: ()->(Float, Float)?) -> (DrawingData, PlotMarkers?) {
    
    // Calculate maximum/minimum/count, and pass it down to base.
    // FIXME: positive and negative segments need to be accumulated separately.
    var it = values.makeIterator()
    let baseResults = base._layoutData(size: size, renderer: renderer, getStackHeight: {
      let base = getStackHeight()
      if let nextValue = it.next() {
        let segmentHeight = adapter.distance(from: originElement, to: nextValue)
        if segmentHeight > 0 {
          return ((base?.0 ?? 0) + segmentHeight, base?.1 ?? 0)
        } else {
          return (base?.0 ?? 0, (base?.1 ?? 0) + segmentHeight)
        }
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
        let segmentHeight = adapter.distance(from: originElement, to: nextValue) * layoutInfo.layout.scale
        var segmentRect: Rect
        switch layoutInfo.layout.orientation {
        case .vertical:
          segmentRect = Rect(origin: Point(layoutInfo.axisLocation,
                                           layoutInfo.layout.origin.y + layoutInfo.positiveValueHeight),
                             size: Size(width: Float(layoutInfo.layout.barSize), height: segmentHeight))
          if segmentHeight < 0 {
            segmentRect.origin.y = layoutInfo.layout.origin.y - layoutInfo.negativeValueHeight
            layoutInfo.negativeValueHeight += -1 * segmentHeight
          } else {
            layoutInfo.positiveValueHeight += segmentHeight
          }
          
        case .horizontal:
          segmentRect = Rect(origin: Point(layoutInfo.layout.origin.x + layoutInfo.positiveValueHeight,
                                           layoutInfo.axisLocation),
                             size: Size(width: segmentHeight, height: Float(layoutInfo.layout.barSize)))
          if segmentHeight < 0 {
            segmentRect.origin.x = layoutInfo.layout.origin.x - layoutInfo.negativeValueHeight
            layoutInfo.negativeValueHeight += -1 * segmentHeight
          } else {
            layoutInfo.positiveValueHeight += segmentHeight
          }
        }
        renderer.drawSolidRect(segmentRect.normalized, fillColor: segmentColor, hatchPattern: segmentHatchPattern)
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

extension StackedBarGraph: _BarGraphProtocol {
  
  public var parent: Base {
    get { return base }
    _modify { yield &base }
    set { base = newValue }
  }
  
  public var barGraph: BarGraph<Base._RootBarGraphSeriesType> {
    get { return base.barGraph }
    _modify { yield &base.barGraph }
    set { base.barGraph = newValue }
  }
}
