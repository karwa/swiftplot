import SwiftPlot
import SVGRenderer
#if canImport(AGGRenderer)
import AGGRenderer
#endif
#if canImport(QuartzRenderer)
import QuartzRenderer
#endif

@available(tvOS 13, watchOS 13, *)
extension BarchartTests {
  
  func testBarchartStackedVertical() throws {
    
    let fileName = "_18_bar_chart_vertical_stacked"
    
    let x:[String] = ["2008","2009","2010","2011"]
    let y:[Float] = [320,-100,420,500]
    let y1:[Float] = [100,100,220,245]

    let barGraph = y.plots.barChart() { graph in
      graph.color = .orange
      graph.graphOrientation = .vertical
      
      graph.label = "Plot 1"
      graph.formatter = .array(x)
      graph.plotTitle.title = "BAR CHART"
      graph.plotLabel.xLabel = "X-AXIS"
      graph.plotLabel.yLabel = "Y-AXIS"
    }.stackedWith(y1) { stack in
      stack.segmentColor = .blue
      stack.segmentLabel = "Plot 2"
    }
    
    try renderAndVerify(barGraph, fileName: fileName)
  }
}
