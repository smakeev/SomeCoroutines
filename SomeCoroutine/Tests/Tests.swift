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

	public func testComprehension() -> [Type] {
		guard let actionBuilder = actionBuilder else { return [] }
		guard let isFinishedBlock = isFinishedBlock else { return [] }
		var resultArray = [Type]()

		while !finished {
			if let result = actionBuilder(iterationNumber) {
				resultArray.append(result)
				if isFinishedBlock(iterationNumber, result) {
					finished = true
				}
			}
			iterationNumber += 1
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
		let fromNegative = SomeGenerator.range(-3, 2)
		XCTAssert(fromNegative.testRangeCreationRun() == [-3, -2, -1, 0, 1])
		let fromNegativeToNegative = SomeGenerator.range(-3, -10)
		XCTAssert(fromNegativeToNegative.testRangeCreationRun() == [-3, -4, -5, -6, -7, -8, -9])
		let fromNegativeToNegativeithStep = SomeGenerator.range(-3, -10, -2)
		XCTAssert(fromNegativeToNegativeithStep.testRangeCreationRun() == [-3, -5, -7, -9])
	}

	func testComprehansion() {
		let array = [0, 1, 2, 3 , 4, 5]
		let fromArray = SG.fromArray(array)
		XCTAssert(fromArray.testComprehension() == [0, 1, 2, 3 , 4, 5])
		let comprehension = SG.comprehension({array[$0] * array[$0]}, iterations: array.count)
		XCTAssert(comprehension.testComprehension() == [0, 1, 4, 9 , 16, 25])
		//only for odd
		let comprehensionOdd = SG<Int>.comprehension({
			guard $0 % 2 != 0 else { return nil }
			return array[$0] * array[$0]

		}, iterations: array.count)
		XCTAssert(comprehensionOdd.testComprehension() == [1, 9, 25])
	}

	func testYieldGeneratorCreation() {
		let generator = SG<Int>.generator() { y in
				let result = y.yield(25)
				if let result = result as? Int {
					y.yield(result)
				}
				y.yield(24)
				y.yield(23)

				let result1 = y.yield(22)
				if let result1 = result1 as? Int {
					y.yield(result1)
				}
				y.subYield(SG.fromArray([1, 2 ,3]))
				y.yield(12)

				return 100 //last value must be returned
		}
		XCTAssert(generator.next(2) == 25)
		XCTAssert(generator.next() == 2)
		XCTAssert(generator.next() == 24)
		XCTAssert(generator.next() == 23)
		XCTAssert(generator.next(-100) == 22)
		XCTAssert(generator.next() == -100)
		XCTAssert(generator.next(80) == 1) //80 is used to test that it could be ignored.
		XCTAssert(generator.next() == 2)
		XCTAssert(generator.next() == 3)
		XCTAssert(generator.next() == 12)
		XCTAssert(generator.next() == 100)
		XCTAssert(generator.next() == nil)
		XCTAssert(generator.next(100) == nil)
		XCTAssert(generator.next() == nil)
		XCTAssert(generator.current == 100)
	}

	func testToArray() {
		let range = SomeGenerator.range(0, 10, 1)
		XCTAssert(range.toArray() == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
		let comprehension = SG.comprehension({$0}, iterations: 5)
		XCTAssert(comprehension.toArray() == [0, 1, 2, 3, 4])
		let arrayOfArrays = SG.comprehension({SG.comprehension({$0}, iterations: ($0 + 1)).toArray()}, iterations: 5)
		XCTAssert(arrayOfArrays.toArray() == [[0],
											  [0, 1],
										      [0, 1, 2],
										      [0, 1, 2, 3],
											  [0, 1, 2, 3, 4]])
	}

	func testNext() {
		let range = SomeGenerator.range(0, 5, 1)
		XCTAssert(range.current == nil)
		XCTAssert(range.next() == 0)
		XCTAssert(range.current == 0)
		XCTAssert(range.next() == 1)
		XCTAssert(range.current == 1)
		XCTAssert(range.next() == 2)
		XCTAssert(range.current == 2)
		XCTAssert(range.next() == 3)
		XCTAssert(range.current == 3)
		XCTAssert(range.next() == 4)
		XCTAssert(range.current == 4)
		XCTAssert(range.next() == nil)
		XCTAssert(range.next() == nil)
		XCTAssert(range.current == 4)

		let comprehension = SG.comprehension({$0}, isFinished:{ iteration, _ in
			return iteration == 2
		} )
		XCTAssert(comprehension.current == nil)
		XCTAssert(comprehension.next() == 0)
		XCTAssert(comprehension.next() == 1)
		XCTAssert(comprehension.next() == 2)
		XCTAssert(comprehension.next() == nil)
		XCTAssert(comprehension.next() == nil)
		XCTAssert(comprehension.current == 2)

	}

	func testForIn() {
		var result = [String]()
		let input  = ["first", "second", "third"]
		let fromArray = SG.fromArray(input)
		for str in fromArray {
			result.append(str)
		}
		XCTAssert(result == input)
		for str in fromArray {
			result.append(str)
		}
		XCTAssert(result == input)
	}

	func testAdditionalParam() {
		let range = SomeGenerator.range(0, 5, 1)
		XCTAssert(range.next()  == 0)
		XCTAssert(range.next(2) == 2)
		XCTAssert(range.next(-1) == nil)
		XCTAssert(range.next() == nil)
		XCTAssert(range.current == 2)

		let range2 = SomeGenerator.range(0, 5, 1)
		XCTAssert(range2.next(2) == 0)
		XCTAssert(range2.next() == 1)

		let randeAdditional = SomeGenerator.range(10, step: 1) {  result, add  in
			if let validAdd = add as? Int {
				return result + validAdd
			} else {
				return result
			}
		}

		XCTAssert(randeAdditional.next(1) == 1)
		XCTAssert(randeAdditional.next(2) == 4)
		XCTAssert(randeAdditional.next(12) == nil)
		XCTAssert(randeAdditional.current == 4)


		let com = SomeGenerator.comprehension({$0}, isFinished: { iter, _ in iter == 10 }, additional: { value, addition in
			if let validAddition = addition as? Int {
				return value + validAddition
			} else {
				return value
			}
		})

		XCTAssert(com.next(1) == 1)
		XCTAssert(com.next(-1) == 0)
		XCTAssert(com.toArray() == [2, 3, 4, 5, 6, 7, 8, 9, 10])
	}

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
