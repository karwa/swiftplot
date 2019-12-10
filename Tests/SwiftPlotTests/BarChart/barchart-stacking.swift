import Foundation
import SwiftPlot
import SVGRenderer
#if canImport(AGGRenderer)
import AGGRenderer
#endif
#if canImport(QuartzRenderer)
import QuartzRenderer
#endif

// Tests for a variety of stacking edge-cases.

@available(tvOS 13, watchOS 13, *)
extension BarchartTests {
  
  /// Draws a vertical stack of homogenous data-sets.
  func testBarchart_stacking_homog_v() throws {
    let barGraph = (5..<20).plots
      .barChart() {
        $0.label = "Existing product"
        $0.color = .orange
        $0.categoryLabels = .custom { String(2000 + $1) }
        
        $0.plotTitle.title  = "Financial Results"
        $0.plotLabel.xLabel = "Year"
        $0.plotLabel.yLabel = "Profit ($m)"
    }.stackedWith((0..<15)) {
      $0.label = "New product"
      $0.color = .green
    }.stackedWith(-10..<1) {
      $0.label = "Bad product"
      $0.color = .red
    }
    try renderAndVerify(barGraph)
  }
  
  /// Draws a horizontal stack of homogenous data-sets.
  func testBarchart_stacking_homog_h() throws {
    let barGraph = (5..<20).plots
      .barChart() {
        $0.label = "Existing product"
        $0.color = .orange
        $0.categoryLabels = .custom { String(2000 + $1) }
        
        $0.graphOrientation = .horizontal
        $0.plotTitle.title  = "Financial Results"
        $0.plotLabel.xLabel = "Profit ($m)"
        $0.plotLabel.yLabel = "Year"
    }.stackedWith((0..<15)) {
      $0.label = "New product"
      $0.color = .green
    }.stackedWith(-10..<1) {
      $0.label = "Bad product"
      $0.color = .red
    }
    try renderAndVerify(barGraph)
  }
  
  /// Draws a vertical stack of heterogeneous data-sets.
  func testBarchart_stacking_hetero_v() throws {
    struct MyStruct { var value: Int8 }
    let factors: [String]  = ["Plot", "Casting", "Direction", "Script", "Score", "Effects"]
    let likes: Data        = Data([0, 16, 3, 0, 15, 1])
    let moderates: [Int]   = [20, 34, 12, 16, 24, 20]
    let dislikes: [Float]  = [-65, -34, -70, -64, -42, -59]
    let haters             = (15...20).lazy.map { MyStruct(value: Int8(-1 * $0)) }
    
    let barGraph = moderates.plots
      .barChart() {
        $0.plotTitle.title  = "Viewer feedback"
        $0.plotLabel.xLabel = "Category"
        $0.plotLabel.yLabel = "Viewers (%)"
        $0.minimumSeparation = 40
        $0.label = "Liked"
        $0.color = .orange
        $0.categoryLabels = .array(factors)
    }.stackedWith(likes) {
      $0.label = "Strongly liked"
      $0.color = .green
    }.stackedWith(dislikes) {
      $0.label = "Disliked"
      $0.color = .red
    }.stackedWith(haters, adapter: .keyPath(\.value)) {
      $0.label = "Strongly disliked"
      $0.color = .darkRed
    }
    try renderAndVerify(barGraph)
  }
  
  /// Draws a horizontal stack of heterogeneous data-sets.
  func testBarchart_stacking_hetero_h() throws {
    struct MyStruct { var value: Int8 }
    let factors: [String]  = ["Plot", "Casting", "Direction", "Script", "Score", "Effects"]
    let likes: Data        = Data([0, 16, 3, 0, 15, 1])
    let moderates: [Int]   = [20, 34, 12, 16, 24, 20]
    let dislikes: [Float]  = [-65, -34, -70, -64, -42, -59]
    let haters             = (15...20).lazy.map { MyStruct(value: Int8(-1 * $0)) }
    
    let barGraph = moderates.plots
      .barChart() {
        $0.graphOrientation = .horizontal
        $0.plotTitle.title  = "Viewer feedback"
        $0.plotLabel.xLabel = "Viewers (%)"
        $0.plotLabel.yLabel = "Category"
        $0.minimumSeparation = 40
        $0.label = "Liked"
        $0.color = .orange
        $0.categoryLabels = .array(factors)
    }.stackedWith(likes) {
      $0.label = "Strongly liked"
      $0.color = .green
    }.stackedWith(dislikes) {
      $0.label = "Disliked"
      $0.color = .red
    }.stackedWith(haters, adapter: .keyPath(\.value)) {
      $0.label = "Strongly disliked"
      $0.color = .darkRed
    }
    try renderAndVerify(barGraph)
  }
}

// Scaling/Margin tests.

@available(tvOS 13, watchOS 13, *)
extension BarchartTests {
  
  func _doTestBarchart_stacking_beyond_series(_ orientation: GraphOrientation) -> Plot {
    return (0..<20).plots
      .barChart() {
        $0.label = "Base"
        $0.color = .darkRed
        $0.minimumSeparation = 4
        $0.graphOrientation = orientation
    }.stackedWith((-25...10).reversed()) {
      $0.label = "Stack"
      $0.color = .pink
    }.stackedWith((-25...20)) {
      $0.label = "Stack 2"
      $0.color = .brown
    }
  }
  
  /// Tests a stacked BarGraph, where the stacks have more data points than the main series.
  func testBarchart_stacking_beyond_series_v() throws {
    let barGraph = _doTestBarchart_stacking_beyond_series(.vertical)
    try renderAndVerify(barGraph)
  }
  
  /// Tests a stacked BarGraph, where the stacks have more data points than the main series.
  func testBarchart_stacking_beyond_series_h() throws {
    let barGraph = _doTestBarchart_stacking_beyond_series(.horizontal)
    try renderAndVerify(barGraph)
  }
  
  func _doTestBarchart_stacking_zero_series_all_neg(_ orientation: GraphOrientation) -> Plot {
    return repeatElement(0, count: 10).plots
      .barChart() {
        $0.label = "Base"
        $0.color = .darkRed
        $0.categoryLabels = .index
        $0.graphOrientation = orientation
    }.stackedWith((-9...0).reversed()) {
      $0.label = "Stack"
      $0.color = .pink
    }.stackedWith((-5...0)) {
      $0.label = "Stack 2"
      $0.color = .brown
    }
  }
  
  /// Tests a stacked BarGraph, where the series has no height and the stacks are all negative.
  func testBarchart_stacking_zero_series_all_neg_v() throws {
    let barGraph = _doTestBarchart_stacking_zero_series_all_neg(.vertical)
    try renderAndVerify(barGraph)
  }
  /// Tests a stacked BarGraph, where the series has no height and the stacks are all negative.
  func testBarchart_stacking_zero_series_all_neg_h() throws {
    let barGraph = _doTestBarchart_stacking_zero_series_all_neg(.horizontal)
    try renderAndVerify(barGraph)
  }
  
  func _doTestBarchart_stacking_zero_series_all_pos(_ orientation: GraphOrientation) -> Plot {
    return repeatElement(0, count: 10).plots
      .barChart() {
        $0.label = "Base"
        $0.color = .darkRed
        $0.categoryLabels = .index
        $0.graphOrientation = orientation
    }.stackedWith((0..<10)) {
      $0.label = "Stack"
      $0.color = .pink
    }.stackedWith((0...5).reversed()) {
      $0.label = "Stack 2"
      $0.color = .brown
    }
  }
  
  /// Tests a stacked BarGraph, where the series has no height and the stacks are all positive.
  func testBarchart_stacking_zero_series_all_pos_v() throws {
    let barGraph = _doTestBarchart_stacking_zero_series_all_pos(.vertical)
    try renderAndVerify(barGraph)
  }
  /// Tests a stacked BarGraph, where the series has no height and the stacks are all positive.
  func testBarchart_stacking_zero_series_all_pos_h() throws {
    let barGraph = _doTestBarchart_stacking_zero_series_all_pos(.horizontal)
    try renderAndVerify(barGraph)
  }
}
