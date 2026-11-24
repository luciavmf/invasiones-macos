//
//  LineOfSight.swift
//  Invasiones
//
//  Port of Mapa.ObtenerPosicionEnLineaDeVision. It only needs walkability, so it
//  works on any WalkableGrid (the map in the game, hand-made grids in tests).
//

extension WalkableGrid {

    /// Walks from (x1,y1) toward (x2,y2) along the Bresenham-style parametric line and
    /// returns the first walkable tile it encounters (port of C# ObtenerPosicionEnLineaDeVision).
    /// Returns `nil` if no walkable tile is found.
    func getLineOfSightPosition(x1: Int, x2: Int, y1: Int, y2: Int) -> (x: Int, y: Int)? {
        var col = Float(x1)
        var row = Float(y1)

        let rowSlope = getRowSlope(x1: x1, x2: x2, y1: y1, y2: y2)
        let colSlope = getColumnSlope(x1: x1, x2: x2, y1: y1, y2: y2)

        if abs(rowSlope) == 1.0 {
            while Int(row.rounded(.down)) != y2 {
                let ci = Int(col.rounded(.down))
                let fi = Int(row.rounded(.down))
                if isWalkable(x: ci, y: fi) { return (ci, fi) }
                row += rowSlope
                col += colSlope
            }
        } else {
            while Int(col.rounded(.down)) != x2 {
                let ci = Int(col.rounded(.down))
                let fi = Int(row.rounded(.down))
                if isWalkable(x: ci, y: fi) { return (ci, fi) }
                row += rowSlope
                col += colSlope
            }
        }
        return nil
    }

    fileprivate func getRowSlope(x1: Int, x2: Int, y1: Int, y2: Int) -> Float {
        if abs(y2 - y1) > abs(x2 - x1) {
            return y2 > y1 ? 1 : -1
        } else {
            let d = Float(abs(y2 - y1)) / Float(abs(x2 - x1))
            return d * (y2 > y1 ? 1 : -1)
        }
    }

    fileprivate func getColumnSlope(x1: Int, x2: Int, y1: Int, y2: Int) -> Float {
        if abs(x2 - x1) > abs(y2 - y1) {
            return x2 > x1 ? 1 : -1
        } else {
            let d = Float(abs(x2 - x1)) / Float(abs(y2 - y1))
            return d * (x2 > x1 ? 1 : -1)
        }
    }
}
