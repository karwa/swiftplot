import SwiftPlot
import SVGRenderer
#if canImport(AGGRenderer)
import AGGRenderer
#endif
#if canImport(QuartzRenderer)
import QuartzRenderer
#endif

@available(tvOS 13, watchOS 13, *)
extension LineChartTests {
  
  func testLineChartSubplotGridStacked() {
    
    let fileName = "_05_sub_plot_grid_stacked_line_chart"
    
    let x:[Float] = [0,100,263,489]
    let y:[Float] = [0,320,310,170]
    
    var plots = [Plot]()
    
    let lineGraph1 = LineGraph<Float,Float>(enablePrimaryAxisGrid: true)
    lineGraph1.addSeries(x, y, label: "Plot 1", color: .lightBlue)
    lineGraph1.plotTitle = PlotTitle("PLOT 1")
    lineGraph1.plotLabel = PlotLabel(xLabel: "X-AXIS", yLabel: "Y-AXIS", labelSize: 12)
    lineGraph1.markerTextSize = 10
    
    let lineGraph2 = LineGraph<Float,Float>(enablePrimaryAxisGrid: true)
    lineGraph2.addSeries(x, y, label: "Plot 2", color: .orange)
    lineGraph2.plotTitle = PlotTitle("PLOT 2")
    lineGraph2.plotLabel = PlotLabel(xLabel: "X-AXIS", yLabel: "Y-AXIS", labelSize: 12)
    lineGraph2.markerTextSize = 10
    
    let lineGraph3 = LineGraph<Float,Float>(enablePrimaryAxisGrid: true)
    lineGraph3.addSeries(x, y, label: "Plot 3", color: .brown)
    lineGraph3.plotTitle = PlotTitle("PLOT 3")
    lineGraph3.plotLabel = PlotLabel(xLabel: "X-AXIS", yLabel: "Y-AXIS", labelSize: 12)
    lineGraph3.markerTextSize = 10
    
    let lineGraph4 = LineGraph<Float,Float>(enablePrimaryAxisGrid: true)
    lineGraph4.addSeries(x, y, label: "Plot 4", color: .green)
    lineGraph4.plotTitle = PlotTitle("PLOT 4")
    lineGraph4.plotLabel = PlotLabel(xLabel: "X-AXIS", yLabel: "Y-AXIS", labelSize: 12)
    lineGraph4.markerTextSize = 10
    
    plots.append(lineGraph1)
    plots.append(lineGraph2)
    plots.append(lineGraph3)
    plots.append(lineGraph4)
    
    let subPlot = SubPlot(numberOfPlots: 4, numberOfRows: 2, numberOfColumns: 2, stackPattern: .gridStacked)
    let svg_renderer = SVGRenderer()
    subPlot.draw(plots: plots,
                 renderer: svg_renderer,
                 fileName: self.svgOutputDirectory+fileName)
    #if canImport(AGGRenderer)
    let agg_renderer = AGGRenderer()
    subPlot.draw(plots: plots,
                 renderer: agg_renderer,
                 fileName: self.aggOutputDirectory+fileName)
    #endif
    #if canImport(QuartzRenderer)
    let quartz_renderer = QuartzRenderer()
    subPlot.draw(plots: plots,
                 renderer: quartz_renderer,
                 fileName: self.coreGraphicsOutputDirectory+fileName)
    #endif
  }
}