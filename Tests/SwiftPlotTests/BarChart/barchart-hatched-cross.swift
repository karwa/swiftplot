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
  
  /// - note: This test is duplicated to also test base64 encoding.
  ///         If the test changes, please update that test, too.
  func testBarchartHatchedCross() throws {
    
    let fileName = "_15_bar_chart_cross_hatched"
    
    let x:[String] = ["2008","2009","2010","2011"]
    let y:[Float] = [320,-100,420,500]
    
    let barGraph = y.plots.barChart() { graph in
      graph.color = .orange
      graph.hatchPattern = .cross
      
      graph.label = "Plot 1"
      graph.formatter = .array(x)
      graph.plotTitle.title = "HATCHED BAR CHART"
      graph.plotLabel.xLabel = "X-AXIS"
      graph.plotLabel.yLabel = "Y-AXIS"
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
