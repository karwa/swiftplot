import XCTest
import SwiftPlot

@available(tvOS 13.0, watchOS 6.0, *)
final class HeatmapTests: SwiftPlotTestCase {

    // Example from:
    // https://scipython.com/book/chapter-7-matplotlib/examples/a-heatmap-of-boston-temperatures/
    func testHeatmap() throws {
        let data: [[Float]] = median_daily_temp_boston_2012
        let heatmap = data.plots.heatmap() {
            $0.plotTitle.title = "Maximum daily temperatures in Boston, 2012"
            $0.plotLabel.xLabel = "Day of the Month"
            $0.colorMap = ColorMap.fiveColorHeatMap.lightened(by: 0.35)
            $0.showGrid = true
            $0.grid.color = Color.gray.withAlpha(0.65)
            
            $0.yFormatter = { String($0.first!) }
            $0.xFormatter = { String($0) }
            $0.valueFormatter = { String($0) }
        }
        try renderAndVerify(heatmap, size: Size(width: 900, height: 450))
    }

    // Tests inverted mapping.
    func testHeatmap_invertedMapping() throws {
        let data: [[Float]] = median_daily_temp_boston_2012
        let heatmap = data.plots.heatmap(mapping: Mapping.Heatmap.linear.inverted) {
            $0.plotTitle.title = "Maximum daily temperatures in Boston, 2012"
            $0.plotLabel.xLabel = "Day of the Month"
            $0.colorMap = ColorMap.fiveColorHeatMap.lightened(by: 0.35)
            $0.showGrid = true
            $0.grid.color = Color.gray.withAlpha(0.65)
        }
        try renderAndVerify(heatmap, size: Size(width: 900, height: 450))
    }
    
    enum Produce {
        case lettuce
        case cucumbers
        case tomatoes
    }
    
    struct Farmer {
        var name: String = ""
        var harvests: [(Produce, Int)] = []
        var ages: [Int] = []
    }
    
    func testHeatmap_keypath() throws {
        let x: [Farmer] = [
            Farmer(name: "Jimbo", harvests: [(.lettuce, 80), (.cucumbers, 60), (.tomatoes, 60)]),
            Farmer(name: "Jones", harvests: [(.lettuce, 10), (.cucumbers, 20), (.tomatoes, 30)]),
        ]
        
        let hm2 = x.plots.heatmap(inner: \.ages) { hm in
            hm.yFormatter = { y in y.base.name }
            hm.xFormatter = { x in x.byteSwapped.description }
            hm.valueFormatter = { $0.description }
        }
        
        let hm = x.plots.heatmap(inner: \.harvests,
                                 mapping: .keyPath(\.1)) {
            $0.xFormatter = { thing in String(describing: thing.0) }
            $0.yFormatter = { thing in String(thing.base.name) }
            $0.valueFormatter = { kvp in String(kvp.1) }
        }

        try renderAndVerify(hm)
    }
}

// Data used to generate Heatmaps.

let median_daily_temp_boston_2012: [[Float]] = [
    /* Jan */
    [
        11.1, 10.2, 1.7, -2.0, 3.9, 8.9, 15.7, 7.3, 4.5, 8.5, 3.6, 5.6, 12.3, 1.3, -7.0, 1.3, 9.0,
        11.2, 0.7, 0.1, -4.9, -1.1, 8.4, 13.5, 6.2, 5.1, 7.8, 7.9, 6.3, 4.6, 8.5
    ],
    /* Feb */
    [
        15.0, 7.4, 3.9, 6.3, 2.4, 10.2, 7.8, 3.5, 8.5, 10.0, 4.0, -0.9, 5.1, 6.7, 6.1, 7.3, 11.8,
        8.4, 7.9, 5.1, 6.9, 13.9, 12.8, 5.7, 7.4, 5.1, 11.2, 9.1, 2.3
    ],
    /* Mar */
    [
        2.8, 1.8, 8.4, 5.7, 3.5, 4.0, 16.9, 20.1, 16.2, 4.6, 14.7, 21.8, 21.9, 14.0, 5.7, 7.9, 9.6,
        23.5, 23.4, 19.5, 25.7, 28.4, 24.6, 15.1, 9.0, 10.0, 9.6, 10.1, 7.8, 10.8, 6.2
    ],
    /* Apr */
    [
        10.6, 11.7, 15.1, 17.9, 11.2, 11.9, 11.2, 10.1, 14.5, 17.3, 12.4, 13.5, 18.6, 21.9, 25.2,
        30.7, 29.0, 16.8, 19.0, 25.2, 25.7, 16.7, 17.4, 14.7, 16.7, 17.3, 14.1, 15.7, 15.2, 12.4
    ],
    /* May */
    [
        10.1, 11.3, 10.0, 13.5, 14.5, 12.4, 15.1, 14.6, 17.3, 19.5, 18.0, 26.8, 26.7, 18.0, 23.0,
        22.9, 21.2, 18.5, 18.9, 21.8, 15.1, 17.3, 21.7, 21.7, 23.4, 30.2, 22.3, 20.8, 19.6, 24.1,
        28.5
    ],
    /* Jun */
    [
        18.6, 16.7, 16.7, 11.7, 13.4, 16.3, 18.5, 26.3, 26.2, 24.5, 23.5, 23.5, 18.3, 20.2, 20.7,
        18.5, 17.4, 18.0, 24.7, 36.3, 35.8, 35.2, 27.3, 28.9, 22.9, 23.0, 25.1, 28.4, 31.9, 32.3
    ],
    /* Jul */
    [
        32.9, 29.1, 30.2, 29.0, 28.4, 26.8, 30.1, 31.7, 28.9, 28.5, 26.7, 30.1, 32.4, 32.9, 32.8,
        31.2, 36.1, 31.7, 23.5, 21.8, 23.4, 28.9, 30.2, 32.8, 28.4, 29.1, 26.3, 22.4, 23.0, 27.2,
        22.8
    ],
    /* Aug */
    [
        25.6, 30.2, 33.4, 27.8, 31.2, 29.5, 25.1, 28.3, 28.5, 28.9, 27.4, 29.0, 30.0, 28.4, 29.0,
        29.6, 30.0, 22.3, 22.9, 23.9, 28.5, 25.6, 30.6, 25.6, 25.2, 24.7, 29.6, 30.1, 24.0, 28.5,
        32.4
    ],
    /* Sep */
    [
        26.7, 22.9, 22.3, 22.8, 27.9, 26.3, 28.0, 27.9, 24.1, 20.6, 22.8, 22.9, 27.9, 27.2, 23.4,
        21.7, 21.2, 24.1, 22.4, 16.7, 17.3, 19.6, 21.9, 19.6, 23.0, 23.3, 20.6, 14.7, 14.1, 15.2
    ],
    /* Oct */
    [
        20.1, 21.8, 17.9, 16.9, 24.7, 25.6, 14.6, 13.4, 14.5, 16.8, 15.2, 12.3, 11.8, 19.5, 23.4,
        17.4, 13.4, 15.7, 20.2, 23.5, 17.9, 20.2, 19.7, 12.8, 15.2, 18.9, 15.6, 13.3, 16.3, 17.4,
        13.5
    ],
    /* Nov */
    [
        13.9, 11.2, 11.9, 11.7, 7.4, 5.2, 7.2, 4.7, 11.7, 13.0, 16.1, 19.1, 17.4, 7.3, 5.2, 7.4,
        8.5, 8.5, 8.9, 9.1, 9.5, 10.2, 9.6, 9.0, 4.7, 7.9, 4.0, 2.3, 6.3, 3.6
    ],
    /* Dec */
    [
        0.1, 11.2, 15.1, 14.0, 14.0, 5.1, 6.8, 8.5, 9.6, 15.7, 13.4, 4.6, 5.6, 9.6, 4.5, 3.9, 7.2,
        10.1, 7.4, 6.2, 11.3, 3.6, 3.5, 4.6, 1.9, 4.0, 8.4, 2.8, 3.0, -1.1, 1.1
    ]
]
