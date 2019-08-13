//
//  Tests.swift
//  Tests
//
//  Created by Sergey Makeev on 13/08/2019.
//  Copyright © 2019 Sergey Makeev. All rights reserved.
//

import XCTest

@testable import SomeCoroutine

extension SomeGenerator {
	public func testRangeCreationRun() -> [Type] {
		guard let rangeGenerator = rangeBuilder else { return [] }
		var resultArray = [Type]()
		while let value = rangeGenerator(self) {
			resultArray.append(value)
			current = value
		}
		return resultArray
	}
}


class Tests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

	func testSimpleGenerator() {
		let range = SomeGenerator.range(0, 10, 1)
		XCTAssert(range.testRangeCreationRun() == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
		let rangeDown = SomeGenerator.range(0, -10, -1)
		XCTAssert(rangeDown.testRangeCreationRun() == [0, -1, -2, -3, -4, -5, -6, -7, -8, -9])
		let range0 = SomeGenerator.range(0, 0, 1)
		XCTAssert(range0.testRangeCreationRun() == [])
		let rangeStep0 = SomeGenerator.range(0, 10, 0)
		XCTAssert(rangeStep0.testRangeCreationRun() == [])
		let rangeStep2 = SomeGenerator.range(0, 10, 2)
		XCTAssert(rangeStep2.testRangeCreationRun() == [0, 2, 4, 6, 8])
		let rangeWrong = SomeGenerator.range(0, 10, -2)
		XCTAssert(rangeWrong.testRangeCreationRun() == [])
		let range2Params = SomeGenerator.range(0, 10)
		XCTAssert(range2Params.testRangeCreationRun() == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
		let range1Param = SomeGenerator.range(10)
		XCTAssert(range1Param.testRangeCreationRun() == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
		let rangeTargetStep = SomeGenerator.range(10, step: 3)
		XCTAssert(rangeTargetStep.testRangeCreationRun() == [0, 3, 6, 9])
		let rangeWrongTargetStep = SomeGenerator.range(10, step: -3)
		XCTAssert(rangeWrongTargetStep.testRangeCreationRun() == [])
	}

	func testComprehansion() {
		let array = [0, 1, 2, 3 , 4, 5]
		let comprehension = SG.comprehension({array[$0] * array[$0]}, iterations: array.count)

		//only for odd
		let comprehensionOdd = SG.comprehension({
				array[$0] * array[$0]

		}, iterations: array.count)
	}

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
