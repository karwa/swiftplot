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
    
    let svg_renderer = SVGRenderer()
    try barGraph.drawGraphAndOutput(fileName: svgOutputDirectory+fileName,
                                    renderer: svg_renderer)
    verifyImage(name: fileName, renderer: .svg)
    #if canImport(AGGRenderer)
    let agg_renderer = AGGRenderer()
    try barGraph.drawGraphAndOutput(fileName: aggOutputDirectory+fileName,
                                    renderer: agg_renderer)
    verifyImage(name: fileName, renderer: .agg)
    #endif
    #if canImport(QuartzRenderer)
    let quartz_renderer = QuartzRenderer()
    try barGraph.drawGraphAndOutput(fileName: coreGraphicsOutputDirectory+fileName,
                                    renderer: quartz_renderer)
    verifyImage(name: fileName, renderer: .coreGraphics)
    #endif
  }
}
