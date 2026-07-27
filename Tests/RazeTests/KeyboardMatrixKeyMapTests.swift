#if os(macOS)
import RazerCore
import XCTest
@testable import Raze

final class KeyboardMatrixKeyMapTests: XCTestCase {
    func testKnownKeysScaleIntoDifferentMatrixSizes() {
        let fullSize = KeyboardMatrixKeyMap.point(
            for: 18,
            dimensions: .init(rows: 6, columns: 22)
        )
        let compact = KeyboardMatrixKeyMap.point(
            for: 18,
            dimensions: .init(rows: 4, columns: 6)
        )

        XCTAssertEqual(fullSize, .init(row: 1, column: 2))
        XCTAssertEqual(compact, .init(row: 1, column: 0))
    }

    func testUnknownKeyFallsBackInsideMatrix() {
        let point = KeyboardMatrixKeyMap.point(
            for: .max,
            dimensions: .init(rows: 1, columns: 1)
        )

        XCTAssertEqual(point, .init(row: 0, column: 0))
    }
}
#endif
