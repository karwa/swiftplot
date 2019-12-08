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
  
  func testBarchartStackedHorizontal() throws {
    
    let fileName = "_19_bar_chart_horizontal_stacked"
    
    let x:[String] = ["2008","2009","2010","2011"]
    let y:[Float] = [320,-100,420,500]
    let y1:[Float] = [100,100,220,245]

    //    barGraph.addSeries(x, y, label: "Plot 1", color: .orange, graphOrientation: .horizontal)
    var barGraph = y.plots
      .barChart(origin: 0)
      .stackedWith(y1, adapter: .linear, origin: 0)
    
    barGraph.barGraph.formatter = .array(x)
    
    barGraph.barGraph.graphOrientation = .horizontal
    barGraph.plotTitle = PlotTitle("BAR CHART")
    barGraph.plotLabel = PlotLabel(xLabel: "X-AXIS", yLabel: "Y-AXIS")
    
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
