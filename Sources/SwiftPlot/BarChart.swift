import Foundation

fileprivate let MAX_DIV: Float = 50
enum Markers {
  static func linearlySpaced(
    range: ClosedRange<Float>,
    length: Float, scale: Float, origin: Float) -> ([Float], [String]) {
    
    let orderOfMagnitude = max(getNumberOfDigits(range.lowerBound), getNumberOfDigits(range.upperBound))
    let valueInterval: Float
    if orderOfMagnitude > 1 {
      if range.upperBound <= pow(Float(10), Float(orderOfMagnitude - 1)) {
        valueInterval = Float(pow(Float(10), Float(orderOfMagnitude - 2)))
      } else {
        valueInterval = Float(pow(Float(10), Float(orderOfMagnitude - 1)))
      }
    } else {
      valueInterval = Float(pow(Float(10), Float(0)))
    }
    
    var pointInterval: Float = valueInterval*scale
    if(length/pointInterval > MAX_DIV){
      pointInterval = (length/pointInterval)*pointInterval/MAX_DIV
    }
    
    // Add locations greater than (or equal to) the origin.
    var locations = [Float]()
    var location = origin
    while location <= length {
      if location + pointInterval < 0 || location < 0 {
        location += pointInterval
        continue
      }
      locations.append(location)
      location += pointInterval
    }
    // Add locations less than the origin.
    location = origin - pointInterval
    while location > 0 {
      locations.append(location)
      location -= pointInterval
    }
    
    let labels = locations.map { "\( (($0 - origin) / scale ).rounded() )" }
    return (locations, labels)
  }
  
  /// Produces markers by formatting the provided values with `formatter`. Locations are determined by the provided closure.
  /// If `count` is greater than the number of elements in `values`, markers will be added with the formatter's empty-value String.
  static func formatting<S>(values: S, formatter: TextFormatter<S.Element>,
                            count: Int, location: (Int)->Float) -> ([Float], [String]) where S: Sequence {
    var locations = [Float]()
    var labels    = [String]()
    locations.reserveCapacity(count)
    labels.reserveCapacity(count)
    
    for (i, value) in values.enumerated() {
      locations.append(location(i))
      labels.append(formatter.callAsFunction(value, offset: i))
    }
    for i in locations.count..<count {
      locations.append(location(i))
      labels.append(formatter.callAsFunction(nil, offset: i))
    }
    return (locations, labels)
  }
}

/// A `BarGraph` is a plot of 1-dimensional data, where each element is displayed as a bar extending from an origin.
///
/// `BarGraph` allows for multiple series of data to be presented alongside each other, any of which
/// may be composed by stacking other 1-dimensional datasets.
public struct BarGraph<SeriesType> where SeriesType: Sequence {
  public typealias Element = SeriesType.Element
  
  public var layout = GraphLayout()
  // Data.
  public var values: SeriesType
  // BarGraph layout properties.
  public var adapter: BarGraphAdapter<Element>
  public var categoryLabels: TextFormatter<Element> = .default
  
  public var graphOrientation = GraphOrientation.vertical
  public var minimumSeparation = 20
  public var minimumSeriesSeparation = 0
  
  public var label = ""
  public var color = Color.orange
  public var hatchPattern = BarGraphSeriesOptions.Hatching.none
  
  public init(_ data: SeriesType, adapter: BarGraphAdapter<Element>) {
    self.values = data
    self.adapter = adapter
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

extension BarGraph: _BarGraphProtocol {
    
  public func _appendLegendLabel(to: inout [(String, LegendIcon)]) {
    to.append((label, .square(color)))
  }
  
  public typealias DrawingData = BarGraphLayoutData
  
  // functions implementing plotting logic
  public func _layoutData(size: Size, renderer: Renderer, getStackHeight: ()->SeriesLayoutData?) -> (DrawingData, PlotMarkers?) {
      var results = DrawingData()
      results.orientation = graphOrientation
      var markers = PlotMarkers()
      
      // - Calculate the shape of the graph.
    
      // The BarGraph is composed of 'columns', and
      // each column is divided in to bars (1 for each series).
      var seriesCount = 0
      var columnCount = 0
      var maxBarHeight: Float = 0
      var minBarHeight: Float = 0
      var it = values.makeIterator()
      // Iterate the columns from the datasets above us.
      while var columnInfo = getStackHeight() {
        // Add our contribution to the column.
        if let nextValue = it.next() {
          let segmentHeight = adapter.heightAboveOrigin(nextValue)
          if segmentHeight > 0 {
            columnInfo.seriesPositiveHeight += segmentHeight
          } else {
            columnInfo.seriesNegativeHeight += segmentHeight
          }
        }
        // We are a series node, so collapse the current series metrics.
        columnInfo.numberOfSeries += 1
        columnInfo.positiveValueHeight = max(columnInfo.positiveValueHeight,
                                             columnInfo.seriesPositiveHeight)
        columnInfo.negativeValueHeight = min(columnInfo.negativeValueHeight,
                                             columnInfo.seriesNegativeHeight)
        // Update the graph-wide metrics.
        columnCount += 1
        seriesCount = max(seriesCount, columnInfo.numberOfSeries)
        maxBarHeight = max(maxBarHeight, columnInfo.positiveValueHeight)
        minBarHeight = min(minBarHeight, columnInfo.negativeValueHeight)
      }
      // Visit any elements we may have remaining.
      while let nextValue = it.next() {
        columnCount += 1
        let segmentHeight = adapter.heightAboveOrigin(nextValue)
        maxBarHeight = max(maxBarHeight, segmentHeight)
        minBarHeight = min(minBarHeight, segmentHeight)
      }
      seriesCount = max(seriesCount, 1)
      maxBarHeight = max(maxBarHeight, minBarHeight)
      minBarHeight = min(minBarHeight, maxBarHeight)
      
      results.numColumns = columnCount
      results.numSeries  = seriesCount
      if Float(columnCount * seriesCount) > size.width {
        print("⚠️ - Graph is too small. Less than 1 pixel per bar.")
      }
      guard columnCount > 0 else { return (results, markers) }
      
      switch graphOrientation {
      case .vertical:
          // - Calculate margins, origin, scale, etc.
          var hasTopMargin = true
          var hasBottomMargin = true
          if minBarHeight < 0 && maxBarHeight <= 0 {
            // All bars are below the origin.
            maxBarHeight = 0
            hasTopMargin = false
          }
          if maxBarHeight >= 0 && minBarHeight >= 0 {
            // All bars are above the origin.
            minBarHeight = 0
            hasBottomMargin = false
          }
          
          let yMarginSize = size.height * 0.1
          let availableHeight = size.height - (hasTopMargin ? yMarginSize : 0)
                                            - (hasBottomMargin ? yMarginSize : 0)
          
          results.scale    = availableHeight / (maxBarHeight - minBarHeight)
          results.origin.y = abs(minBarHeight * results.scale)
                             + (hasBottomMargin ? yMarginSize : 0)
          results.origin.y.round()

          // TODO: Invetigate using `AdjustsPlotSize` protocol rather than non-integer separations.
          
          // Lay out the columns (each maybe containing multiple bars).
          let spaceForColumns = size.width - Float((columnCount + 1) * minimumSeparation)
          results.columnSize  = Int((spaceForColumns / Float(columnCount)).rounded(.down))
          results.columnSize  = max(results.columnSize, seriesCount)

          // If the number of columns is large, rounding to integer bar-widths can leave
          // a large space. Distribute that space as additional separation.
          // Even though this un-integers the bar locations, it results in overall better charts.
          results.columnSeparation = (size.width - Float(columnCount * results.columnSize)) /
                                     Float(columnCount + 1)
          if results.columnSeparation < Float(minimumSeparation) {
            print("⚠️ - Not enough space to honour minimum column separation. " +
                  "Bars would be less than 1 pixel. Using \(results.columnSeparation)")
          }
          
          // Lay out the series.
          let spaceForBars = Float(results.columnSize - ((seriesCount - 1) * minimumSeriesSeparation))
          results.barSize  = Int((spaceForBars / Float(seriesCount)).rounded(.down))
          results.barSize  = max(results.barSize, 1)
          // As above, the rounding may lead to gaps.
          results.seriesSeparation = Float(results.columnSize - (seriesCount * results.barSize)) /
                                     Float(seriesCount - 1)
          if results.seriesSeparation < Float(minimumSeriesSeparation) {
            print("⚠️ - Not enough space to honour minimum series separation. " +
              "Bars would be less than 1 pixel. Using \(results.seriesSeparation)")
          }
          
          (markers.yMarkers, markers.yMarkersText) = Markers.linearlySpaced(
            range: minBarHeight...maxBarHeight,
            length: size.height,
            scale: results.scale, origin: results.origin.y)
          
          // - Calculate X marker locations.
          // TODO: Do not show all x-markers if there are too many bars.
          (markers.xMarkers, markers.xMarkersText) = Markers.formatting(
            values: values, formatter: categoryLabels,
            count: columnCount, location: results.axisMarkerLocationForBar)
          
          
        case .horizontal:
          // - Calculate margins, origin, scale, etc.
          var hasLeftMargin = true
          var hasRightMargin = true
          if minBarHeight < 0 && maxBarHeight <= 0 {
            // All bars are below the origin.
            maxBarHeight = 0
            hasRightMargin = false
            // FIXME: plot markers on top?
          }
          if maxBarHeight >= 0 && minBarHeight >= 0 {
            // All bars are above the origin.
            minBarHeight = 0
            hasLeftMargin = false
          }
          
          let xMarginSize = size.width * 0.1
          let availableWidth = size.width - (hasLeftMargin ? xMarginSize : 0)
                                          - (hasRightMargin ? xMarginSize : 0)
          
          results.scale = availableWidth / (maxBarHeight - minBarHeight)
          results.origin.x = abs(minBarHeight * results.scale)
                             + (hasLeftMargin ? xMarginSize : 0)
          results.origin.x.round()
          
          // TODO: Invetigate using `AdjustsPlotSize` protocol rather than non-integer separations.
          
          // Lay out the columns (each maybe containing multiple bars).
          let spaceForColumns = size.height - Float((columnCount + 1) * minimumSeparation)
          results.columnSize = Int((spaceForColumns / Float(columnCount)).rounded(.down))
          results.columnSize = max(results.columnSize, seriesCount)
          // If the number of columns is large, rounding to integer bar-widths can leave
          // a large space. Distribute that space as additional separation.
          // Even though this un-integers the bar locations, it results in overall better charts.
          results.columnSeparation = (size.height - Float(columnCount * results.columnSize)) /
                                     Float(columnCount + 1)
          // Requiring 1 pixel per bar means we can't always honour the minimum separation.
          if results.columnSeparation < Float(minimumSeparation) {
            print("⚠️ - Not enough space to honour minimum column separation. " +
                  "Bars would be less than 1 pixel. Using \(results.columnSeparation)")
          }
          
          // Lay out the series.
          let spaceForBars = Float(results.columnSize - ((seriesCount - 1) * minimumSeriesSeparation))
          results.barSize  = Int((spaceForBars / Float(seriesCount)).rounded(.down))
          results.barSize  = max(results.barSize, 1)
          // As above, the rounding may lead to gaps.
          results.seriesSeparation = Float(results.columnSize - (seriesCount * results.barSize)) /
                                     Float(seriesCount - 1)
          if results.seriesSeparation < Float(minimumSeriesSeparation) {
            print("⚠️ - Not enough space to honour minimum series separation. " +
                  "Bars would be less than 1 pixel. Using \(results.seriesSeparation)")
          }

          // - Calculate X marker locations.
          (markers.xMarkers, markers.xMarkersText) = Markers.linearlySpaced(
            range: minBarHeight...maxBarHeight,
            length: size.width,
            scale: results.scale,
            origin: results.origin.x)

        // - Calculate Y marker locations.
        // TODO: Do not show all y-markers if there are too many bars.
        (markers.yMarkers, markers.yMarkersText) = Markers.formatting(
          values: values, formatter: categoryLabels,
          count: columnCount, location: results.axisMarkerLocationForBar)
      }
      return (results, markers)
  }
  
  //functions to draw the plot
  public func _drawData(_ data: DrawingData, size: Size, renderer: Renderer,
                        drawStack: (inout BarLayoutData)->Bool) {
    switch graphOrientation {
    case .vertical:
      var it = values.makeIterator()
      for columnIdx in 0..<data.numColumns {
        var barLayoutData = BarLayoutData(layout: data,
                                          axisLocation: data.axisLocationForBar(columnIdx),
                                          positiveValueHeight: 0, negativeValueHeight: 0)
        if let seriesValue = it.next() {
          // Draw the segment from the main series.
          let segmentHeight = (adapter.heightAboveOrigin(seriesValue) * data.scale).rounded(.up)
          let rect = Rect(origin: Point(barLayoutData.axisLocation, data.origin.y),
                          size: Size(width: Float(data.barSize), height: segmentHeight))
          renderer.drawSolidRect(rect, fillColor: color, hatchPattern: hatchPattern)
          // Update layout data.
          if segmentHeight > 0 {
            barLayoutData.positiveValueHeight = segmentHeight
          } else {
            barLayoutData.negativeValueHeight = segmentHeight
          }
        }
        // Call up the chain to draw the rest of this column.
        _ = drawStack(&barLayoutData)
      }
      assert(it.next() == nil, "BarGraph main series has undrawn data")
      var testData = BarLayoutData(layout: data)
      assert(drawStack(&testData) == false, "BarGraph stacks have undrawn data")
          
    case .horizontal:
      var it = values.makeIterator()
      for columnIdx in 0..<data.numColumns {
        var barLayoutData = BarLayoutData(layout: data,
                                          axisLocation: data.axisLocationForBar(columnIdx),
                                          positiveValueHeight: 0, negativeValueHeight: 0)
        if let seriesValue = it.next() {
          // Draw the bar from the main series.
          let segmentHeight = (adapter.heightAboveOrigin(seriesValue) * data.scale).rounded(.up)
          let rect = Rect(origin: Point(data.origin.x, barLayoutData.axisLocation),
                          size: Size(width: segmentHeight, height: Float(data.barSize)))
          renderer.drawSolidRect(rect, fillColor: color, hatchPattern: hatchPattern)
          // Update layout data.
          if segmentHeight > 0 {
            barLayoutData.positiveValueHeight = segmentHeight
          } else {
            barLayoutData.negativeValueHeight = segmentHeight
          }
        }
        // Call up the chain to draw the rest of this column.
        _ = drawStack(&barLayoutData)
      }
      assert(it.next() == nil, "BarGraph main series has undrawn data")
      var testData = BarLayoutData(layout: data)
      assert(drawStack(&testData) == false, "BarGraph stacks have undrawn data")
    }
  }
}

extension BarGraph {
  public typealias _RootBarGraphSeriesType = SeriesType
  public var barGraph: BarGraph<SeriesType> {
    get { return self }
    _modify { yield &self }
    set { self = newValue }
  }
}





public struct TextFormatter<T> {
  private let _format: (T?, Int) -> String
  private init(custom: @escaping (T?, Int)->String) {
    self._format = custom
  }
  
  public func callAsFunction(_ val: T?, offset: Int) -> String {
    _format(val, offset)
  }
  public static var `default`: TextFormatter<T> {
    return TextFormatter { val, idx in val.map { String(describing: $0) } ?? "" }
  }
  public static var index: TextFormatter<T> {
    return TextFormatter { _, idx in String(idx) }
  }
  public static func custom(_ formatter: @escaping (T?, Int)->String) -> TextFormatter<T> {
    return TextFormatter(custom: formatter)
  }
  public static func array<C>(_ array: C) -> TextFormatter<T>
    where C: RandomAccessCollection, C.Element == String {
    return TextFormatter { [array] _, offset in
      guard array.count > offset else { return "" }
      return array[array.index(array.startIndex, offsetBy: offset)]
    }
  }
}

public struct BarGraphAdapter<T> {
  var heightAboveOrigin: (T) -> Float
  
  public init(heightAboveOrigin: @escaping (T) -> Float) {
    self.heightAboveOrigin = heightAboveOrigin
  }
}

// Default adapters for numeric types.

extension BarGraphAdapter where T: BinaryFloatingPoint {
  public static var linear: BarGraphAdapter {
    return BarGraphAdapter(heightAboveOrigin: { Float($0) })
  }
}
extension BarGraphAdapter where T: FixedWidthInteger {
  public static var linear: BarGraphAdapter {
    return BarGraphAdapter(heightAboveOrigin: { Float($0) })
  }
}

// Keypath adapters.

extension BarGraphAdapter {
  
  // Keypath to numeric type.
  
  public static func keyPath<Element>(_ kp: KeyPath<T, Element>, origin: Element = 0) -> BarGraphAdapter
    where Element: BinaryFloatingPoint {
      return BarGraphAdapter(heightAboveOrigin: { Float($0[keyPath: kp] - origin) })
  }
  
  public static func keyPath<Element>(_ kp: KeyPath<T, Element>, origin: Element = 0) -> BarGraphAdapter
    where Element: FixedWidthInteger {
    return BarGraphAdapter(heightAboveOrigin: { Float($0[keyPath: kp] - origin) })
  }
  
  // Keypath with origin expressed as T.

  public static func keyPath<Element>(_ kp: KeyPath<T, Element>, origin: T) -> BarGraphAdapter
    where Element: BinaryFloatingPoint {
      return .keyPath(kp, origin: origin[keyPath: kp])
  }
  
  public static func keyPath<Element>(_ kp: KeyPath<T, Element>, origin: T) -> BarGraphAdapter
    where Element: FixedWidthInteger {
      return .keyPath(kp, origin: origin[keyPath: kp])
  }
}

// Note: These cannot be nested in the BarGraph because we
// need them to be non-generic for stacking.
public enum GraphOrientation {
    case vertical
    case horizontal
}

public struct BarGraphLayoutData {
  /// The total number of columns (each column consisting of multiple series)
  var numColumns = 0
  /// The total number of series (each series consisting of multiple stacked datasets)
  var numSeries = 1
  /// The location of the origin (in pixel coordinates).
  /// Positive bars should be drawn above this point's Y-coordinate (when vertical),
  /// or at a greater X-coordinate (when horizontal).
  var origin: Point = .zero
  /// The scaling factor to apply when drawing, in points/pixel.
  var scale: Float = 1
  /// The graph orientation.
  var orientation = GraphOrientation.vertical
  /// The size of the non-variable dimension, in pixels, of each column
  /// (If orientation == .vertical, this is the width. If orientation == .horizontal, the height).
  var columnSize = 0
  /// The size of the non-variable dimention, in pixels, of each series
  /// (If orientation == .vertical, this is the width. If orientation == .horizontal, the height).
  var barSize = 0
  /// The distance to leave between each column, in pixels.
  var columnSeparation: Float = 0
  /// The distance to leave between each series, in pixels.
  var seriesSeparation: Float = 0
  
  func axisLocationForBar(_ index: Int) -> Float {
    Float(index * columnSize) // bar widths.
      + Float(index + 1) * columnSeparation  // spacing.
  }
  func axisMarkerLocationForBar(_ index: Int) -> Float {
    axisLocationForBar(index)
      + Float(columnSize) * 0.5  // center on bar.
  }
}

public struct BarLayoutData {
  var layout: BarGraphLayoutData
  var axisLocation: Float = 0
  var positiveValueHeight: Float = 0
  var negativeValueHeight: Float = 0
}

public struct SeriesLayoutData {
  var numberOfSeries = 0
  var seriesPositiveHeight: Float = 0
  var seriesNegativeHeight: Float = 0
  
  var positiveValueHeight: Float = 0
  var negativeValueHeight: Float = 0
}


// MARK: - BarGraphProtocol and defaults.


/// This protocol exists to support BarGraph.
/// Do not try to conform to this protocol.
public protocol _BarGraphProtocol: Plot, HasGraphLayout {
  
// Chained HasGraphLayout.
// -----------------------
//
// BarGraphProtocol works by mirroring the layout/drawing calls from `HasGraphLayout`, with
// versions that allow passing information down to the root BarGraph<T>.
//
// Each layer of the stack gets a closure from its children, wraps it in a closure which
// incorporates its own data, and (except for the root BarGraph<T>), passes that wrapped closure
// down to its parent. Eventually, the root BarGraph<T> will call this closure to communicate
// with its children.
  
  // Appends legend information for this segment to the given array.
  func _appendLegendLabel(to: inout [(String, LegendIcon)])
  
  // Lays out the bar from this segment down.
  // `getStackHeight` returns a tuple of (positiveSegmentHeight, negativeSegmentHeight).
  func _layoutData(size: Size, renderer: Renderer,
                   getStackHeight: ()->SeriesLayoutData?
  ) -> (DrawingData, PlotMarkers?)
  
  // Draws the bar from this segment down.
  // Update the `BarLayoutData` to let successive segments know the positive/negative bar height.
  func _drawData(_ data: DrawingData, size: Size, renderer: Renderer,
                 drawStack: (inout BarLayoutData)->Bool)
  
  // A magic associated type which gets funnelled down the chain of generic wrappers,
  // finally terminating at the root `BarGraph`
  associatedtype _RootBarGraphSeriesType: Sequence
  
  /// The `BarGraph`.
  var barGraph: BarGraph<_RootBarGraphSeriesType> { get set }
}

// Forward `HasGraphLayout` requirements to our chaining versions.
extension _BarGraphProtocol {
  
  public var legendLabels: [(String, LegendIcon)] {
    var labels = [(String, LegendIcon)]()
    _appendLegendLabel(to: &labels)
    labels.reverse()
    return labels
  }
  
  public func layoutData(size: Size, renderer: Renderer) -> (DrawingData, PlotMarkers?) {
    // This gets called when we are at the top of the stack.
    // We have no children, so the closure we pass in terminates the chain.
    return _layoutData(size: size, renderer: renderer, getStackHeight: { nil })
  }
  
  public func drawData(_ data: DrawingData, size: Size, renderer: Renderer) {
    // This gets called when we are at the top of the stack.
    // We have no children, so the closure we pass in terminates the chain.
    _drawData(data, size: size, renderer: renderer, drawStack: { _ in false })
  }
}

/// This protocol exists to support BarGraph.
/// Do not try to conform to this protocol.
public protocol _BarGraphChildProtocol: _BarGraphProtocol {

// Chain traversal.
// ----------------
//
// This protocol has been split from BarGraphProtocol so that the root
// BarGraph<T> itself doesn't need to have a parent.
  
  associatedtype _Parent: _BarGraphProtocol
  
  /// The stack or series below this element of the `BarGraph`.
  var parent: _Parent { get set }
}

extension _BarGraphChildProtocol {
  
  public var layout: GraphLayout {
     get { return parent.layout }
     _modify { yield &parent.layout }
     set { parent.layout = newValue }
   }
  
  public var barGraph: BarGraph<_Parent._RootBarGraphSeriesType> {
    get { return parent.barGraph }
    _modify { yield &parent.barGraph }
    set { parent.barGraph = newValue }
  }
}


// MARK: - StackedBarGraph.


public struct StackedBarGraph<Base, SeriesType> where SeriesType: Sequence, Base: _BarGraphProtocol {
  public typealias Element = SeriesType.Element
  
  fileprivate var dataKind: DataKind
  public var parent: Base
  public var values: SeriesType
  public var adapter: BarGraphAdapter<Element>
  
  public var label = ""
  public var color = Color.blue
  public var hatchPattern = BarGraphSeriesOptions.Hatching.none
  
  fileprivate enum DataKind {
    case stack
    case series
  }
}

extension StackedBarGraph: _BarGraphChildProtocol {

  public struct DrawingData {
    var baseData: Base.DrawingData!
  }
  
  public func _appendLegendLabel(to: inout [(String, LegendIcon)]) {
    to.append((label, .square(color)))
    parent._appendLegendLabel(to: &to)
  }
  
  public func _layoutData(size: Size, renderer: Renderer,
                          getStackHeight: ()->SeriesLayoutData?) -> (DrawingData, PlotMarkers?) {

    // Call 'base._layoutData' so this filters down to the root bar chart,
    // but wrap the closure we were given (from higher up) so we add the next value
    // of our height each time it is executed.
    var it = values.makeIterator()
    let baseResults = parent._layoutData(size: size, renderer: renderer, getStackHeight: {
      
      // Get the info from all the data above us.
      let base = getStackHeight()
      if let nextValue = it.next() {
        var layoutData = base ?? SeriesLayoutData()
        let segmentHeight = adapter.heightAboveOrigin(nextValue)
        if segmentHeight > 0 {
          layoutData.seriesPositiveHeight += segmentHeight
        } else {
          layoutData.seriesNegativeHeight += segmentHeight
        }
        
        // FIXME: We need to collapse the stack EVEN IF there is no data.
        
        switch dataKind {
        case .series:
          // Collapse the series info.
          layoutData.positiveValueHeight = max(layoutData.positiveValueHeight,
                                               layoutData.seriesPositiveHeight)
          layoutData.negativeValueHeight = min(layoutData.negativeValueHeight,
                                               layoutData.seriesNegativeHeight)
          layoutData.numberOfSeries += 1
          layoutData.seriesPositiveHeight = 0
          layoutData.seriesNegativeHeight = 0
        case .stack:
          break
        }
        return layoutData
      }
      return base
    })
    return (DrawingData(baseData: baseResults.0), baseResults.1)
  }
  
  public func _drawData(_ data: DrawingData, size: Size, renderer: Renderer,
                        drawStack: (inout BarLayoutData)->Bool) {
    
    // Call 'base._layoutData' so this filters down to the root bar chart,
    // but wrap the closure we were given (from higher up) so we draw the next value
    // of our height before letting the next stack draw its segment.
    var it = values.makeIterator()
    parent._drawData(data.baseData, size: size, renderer: renderer, drawStack: { layoutInfo in
      switch dataKind {
      case .series:
        // If this is a series node, *always* advance the axis location.
        // Even if this series itself doesn't have any data (`it.next() == nil`).
        layoutInfo.axisLocation += Float(layoutInfo.layout.barSize) + layoutInfo.layout.seriesSeparation
        layoutInfo.positiveValueHeight = 0
        layoutInfo.negativeValueHeight = 0
        fallthrough
        
      case .stack:
        guard let nextValue = it.next() else {
          return drawStack(&layoutInfo)
        }
        // Draw our segment.
        let segmentHeight = adapter.heightAboveOrigin(nextValue) * layoutInfo.layout.scale
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
        renderer.drawSolidRect(segmentRect.normalized, fillColor: color, hatchPattern: hatchPattern)
        
        // Draw the next segment in the chain.
        return drawStack(&layoutInfo)
      }
    })
  }
}


// MARK: - SequencePlots and stacking API.


extension SequencePlots {
  public func barChart(
    adapter: BarGraphAdapter<Base.Element>,
    style: (inout BarGraph<Base>)->Void = { _ in }
  ) -> BarGraph<Base> {
    var graph = BarGraph(base, adapter: adapter)
    style(&graph)
    return graph
  }
}

// Default adapter for BinaryFloatingPoint.
extension SequencePlots where Base.Element: BinaryFloatingPoint {
  public func barChart(
    style: (inout BarGraph<Base>)->Void = { _ in }
  ) -> BarGraph<Base> {
    return self.barChart(adapter: .linear, style: style)
  }
}

// Default adapter for Stride: FixedWidthInteger.
extension SequencePlots where Base.Element: FixedWidthInteger {
  public func barChart(
    style: (inout BarGraph<Base>)->Void = { _ in }
  ) -> BarGraph<Base> {
    return self.barChart(adapter: .linear, style: style)
  }
}

extension _BarGraphProtocol {
  
  // Stacking.
  public func stackedWith<S>(
    _ stackSeries: S,
    adapter: BarGraphAdapter<S.Element>,
    style: (inout StackedBarGraph<Self, S>)->Void = { _ in }) -> StackedBarGraph<Self, S>
    where S: Sequence {
      var stack = StackedBarGraph(dataKind: .stack, parent: self, values: stackSeries, adapter: adapter)
      style(&stack)
      return stack
  }
  
  // Default adapter for BinaryFloatingPoint.
  public func stackedWith<S>(
    _ stackSeries: S,
    style: (inout StackedBarGraph<Self, S>)->Void = { _ in }) -> StackedBarGraph<Self, S>
    where S: Sequence, S.Element: BinaryFloatingPoint {
      return stackedWith(stackSeries, adapter: .linear, style: style)
  }
  
  // Default adapter for FixedWidthInteger.
  public func stackedWith<S>(
    _ stackSeries: S,
    style: (inout StackedBarGraph<Self, S>)->Void = { _ in }) -> StackedBarGraph<Self, S>
    where S: Sequence, S.Element: FixedWidthInteger {
      return stackedWith(stackSeries, adapter: .linear, style: style)
  }
  
  // Series.
  public func alongside<S>(
    _ stackSeries: S,
    adapter: BarGraphAdapter<S.Element>,
    style: (inout StackedBarGraph<Self, S>)->Void = { _ in }) -> StackedBarGraph<Self, S>
    where S: Sequence {
      var stack = StackedBarGraph(dataKind: .series, parent: self, values: stackSeries, adapter: adapter)
    style(&stack)
    return stack
  }
  
  // Default adapter for BinaryFloatingPoint.
  public func alongside<S>(
    _ stackSeries: S,
    style: (inout StackedBarGraph<Self, S>)->Void = { _ in }) -> StackedBarGraph<Self, S>
    where S: Sequence, S.Element: BinaryFloatingPoint {
      return alongside(stackSeries, adapter: .linear, style: style)
  }
  
  // Default adapter for FixedWidthInteger.
  public func alongside<S>(
    _ stackSeries: S,
    style: (inout StackedBarGraph<Self, S>)->Void = { _ in }) -> StackedBarGraph<Self, S>
    where S: Sequence, S.Element: FixedWidthInteger {
      return alongside(stackSeries, adapter: .linear, style: style)
  }
}
