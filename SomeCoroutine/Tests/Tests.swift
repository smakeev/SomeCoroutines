//
//  Tests.swift
//  Tests
//
//  Created by Sergey Makeev on 13/08/2019.
//  Copyright © 2019 Sergey Makeev. All rights reserved.
//

import XCTest

@testable import SomeCoroutine

class Tests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

	func testSimpleGenerator() {
		let range = SG.range(0, 10, 1)
		XCTAssert(range.toArray() == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
		let rangeDown = SG.range(0, -10, -1)
		XCTAssert(rangeDown.toArray() == [0, -1, -2, -3, -4, -5, -6, -7, -8, -9])
		let range0 = SG.range(0, 0, 1)
		XCTAssert(range0.toArray() == [])
		let rangeStep0 = SG.range(0, 10, 0)
		XCTAssert(rangeStep0.toArray() == [])
		let rangeStep2 = SG.range(0, 10, 2)
		XCTAssert(rangeStep2.toArray() == [0, 2, 4, 6, 8])
		let rangeWrong = SG.range(0, 10, -2)
		XCTAssert(rangeWrong.toArray() == [])
		let range2Params = SG.range(0, 10)
		XCTAssert(range2Params.toArray() == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
		let range1Param = SG.range(10)
		XCTAssert(range1Param.toArray() == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
		let rangeTargetStep = SG.range(10, step: 3)
		XCTAssert(rangeTargetStep.toArray() == [0, 3, 6, 9])
		let rangeWrongTargetStep = SG.range(10, step: -3)
		XCTAssert(rangeWrongTargetStep.toArray() == [])
		let fromNegative = SG.range(-3, 2)
		XCTAssert(fromNegative.toArray() == [-3, -2, -1, 0, 1])
		let fromNegativeToNegative = SG.range(-3, -10)
		XCTAssert(fromNegativeToNegative.toArray() == [-3, -4, -5, -6, -7, -8, -9])
		let fromNegativeToNegativeithStep = SG.range(-3, -10, -2)
		XCTAssert(fromNegativeToNegativeithStep.toArray() == [-3, -5, -7, -9])
	}

	func testComprehansion() {
		let array = [0, 1, 2, 3, 4, 5]
		let fromArray = SG.fromArray(array)
		XCTAssert(fromArray.toArray() == [0, 1, 2, 3 , 4, 5])
		let comprehension = SG.comprehension({array[$0] * array[$0]}, iterations: array.count)
		XCTAssert(comprehension.toArray() == [0, 1, 4, 9 , 16, 25])
		//only for odd
		let comprehensionOdd = SG<Int>.comprehension({
			guard $0 % 2 != 0 else { return nil }
			return array[$0] * array[$0]

		}, iterations: array.count)
		let result = comprehensionOdd.toArray()
		print(result)
		XCTAssert(result == [1, 9, 25])
	}

	func testYieldGeneratorCreation() {
		let generator = SG<Int>.generator() { y in
				let result = try y.yield(25)
				if let result = result as? Int {
					try y.yield(result)
				}
				try y.yield(24)
				try y.yield(23)

				let result1 = try y.yield(22)
				if let result1 = result1 as? Int {
					try y.yield(result1)
				}
				try y.subYield(SG.fromArray([1, 2 ,3]))
				try y.yield(12)

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


		let generator1 = SG<Int>.generator() { y in
			try y.subYield(SG<Int>.generator() { y in
				let result = try y.yield(25)
				if let result = result as? Int {
					try y.yield(result)
				}
				try y.yield(24)
				try y.yield(23)

				let result1 = try y.yield(22)
				if let result1 = result1 as? Int {
					try y.yield(result1)
				}
				try y.subYield(SG.fromArray([1, 2 ,3]))
				try y.yield(12)

				return 100 //last value must be returned
			})
			return 100 //last value must be returned
		}
		XCTAssert(generator1.next(2) == 25)
		XCTAssert(generator1.next() == 2)
		XCTAssert(generator1.next() == 24)
		XCTAssert(generator1.next() == 23)
		XCTAssert(generator1.next(-100) == 22)
		XCTAssert(generator1.next() == -100)
		XCTAssert(generator1.next(80) == 1) //80 is used to test that it could be ignored.
		XCTAssert(generator1.next() == 2)
		XCTAssert(generator1.next() == 3)
		XCTAssert(generator1.next() == 12)
		XCTAssert(generator1.next() == 100)
		XCTAssert(generator1.next() == 100)
		XCTAssert(generator1.next() == nil)
		XCTAssert(generator1.next(100) == nil)
		XCTAssert(generator1.next() == nil)
		XCTAssert(generator1.current == 100)

		let generator2 = SG<Int>.generator() { y in
			try y.subYield(SG<Int>.generator() { y in
				try y.subYield(SG<Int>.generator() { y in
				let result = try y.yield(25)
				if let result = result as? Int {
					try y.yield(result)
				}
				try y.yield(24)
				try y.yield(23)

				let result1 = try y.yield(22)
				if let result1 = result1 as? Int {
					try y.yield(result1)
				}
				try y.subYield(SG.fromArray([1, 2 ,3]))
				try y.yield(12)

				return 100 //last value must be returned
			})
			return 100 //last value must be returned
		})
		return 100
	}
		XCTAssert(generator2.next(2) == 25)
		XCTAssert(generator2.next() == 2)
		XCTAssert(generator2.next() == 24)
		XCTAssert(generator2.next() == 23)
		XCTAssert(generator2.next(-100) == 22)
		XCTAssert(generator2.next() == -100)
		XCTAssert(generator2.next(80) == 1) //80 is used to test that it could be ignored.
		XCTAssert(generator2.next() == 2)
		XCTAssert(generator2.next() == 3)
		XCTAssert(generator2.next() == 12)
		XCTAssert(generator2.next() == 100)
		XCTAssert(generator2.next() == 100)
		XCTAssert(generator2.next() == 100)
		XCTAssert(generator2.next() == nil)
		XCTAssert(generator2.next(100) == nil)
		XCTAssert(generator2.next() == nil)
		XCTAssert(generator2.current == 100)
}

	func testToArray() {
		let range = SG.range(0, 10, 1)
		XCTAssert(range.toArray() == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
		let comprehension = SG.comprehension({$0}, iterations: 5)
		XCTAssert(comprehension.toArray() == [0, 1, 2, 3, 4])
		let arrayOfArrays = SG.comprehension({SG.comprehension({$0}, iterations: ($0 + 1)).toArray()}, iterations: 5)
		XCTAssert(arrayOfArrays.toArray() == [[0],
											  [0, 1],
										      [0, 1, 2],
										      [0, 1, 2, 3],
											  [0, 1, 2, 3, 4]])

		let yieldGen = SG<Int>.generator() { y in
			try y.yield(0)
			try y.subYield(SG.range(1, 100))
			let array = SG.range(100, 201, 1).toArray()
			try y.subYield(SG.comprehension({array[$0]}, iterations: array.count))
			try y.subYield(SG.generator() { y in
			try	y.subYield(SG.range(201, 999))
				return 999
			})
			return 1000
		}

		let arrayToCompare = SG<Int>.range(1001).toArray()
		XCTAssert(yieldGen.toArray() == arrayToCompare)
	}

	func testNext() {
		let range = SG.range(0, 5, 1)
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
		result = [String]()

		let generator = SG<String>.generator() { y in
			try y.yield("first")
			try y.subYield(SG<String>.generator() { y in
				return "second"
			})
			return "third"
		}

		for str in generator {
			result.append(str)
		}
		XCTAssert(result == input)
	}

	func testAdditionalParam() {
		let range = SG.range(0, 5, 1)
		XCTAssert(range.next()  == 0)
		XCTAssert(range.next(2) == 2)
		XCTAssert(range.next(-1) == nil)
		XCTAssert(range.next() == nil)
		XCTAssert(range.current == 2)

		let range2 = SG.range(0, 5, 1)
		XCTAssert(range2.next(2) == 0)
		XCTAssert(range2.next() == 1)

		let randeAdditional = SG.range(10, step: 1) {  result, add  in
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


		let com = SG.comprehension({$0}, isFinished: { iter, _ in iter == 10 }, additional: { value, addition in
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

func testCancel() {
		let gen = SG<Int>.generator {
			try $0.yield(0)
			try $0.yield(1)
			try $0.yield(2)
			try $0.yield(3)
			return 4
		}
		let promise = expectation(description: "Wait for generator deallocation (exception in yields block")
		gen.deinitPromise = {
				promise.fulfill()
			}
		XCTAssert(gen.next() == 0)
		gen.cancel()
		XCTAssert(gen.next() == nil)
		XCTAssert(gen.current == 0)
		wait(for: [promise], timeout: 1)
	}

	func testDealloc() {
		func sub(_ promise: XCTestExpectation) {
			let gen = SG<Int>.generator {
				try $0.yield(0)
				try $0.yield(1)
				try $0.yield(2)
				try $0.yield(3)

				return 4
			}
			gen.deinitPromise = {
				promise.fulfill()
			}
			XCTAssert(gen.next() == 0)
		}
		let promise = expectation(description: "Wait for generator deallocation (exception in yields block")
		sub(promise)
		print("AFTER")
		wait(for: [promise], timeout: 1)
	}

//coroutine tests

	func testCoroutine() {
		let g1 = SG<Int>.range(10)
		let g2 = SG<Int>.range(10, 20, 1)
		let g3 = SG<Int>.range(20, 30, 1)
		let coroutine = SC<Int>.iterationsCoroutine(3)
		coroutine.add(g1).add(g2).add(g3).onValue {
			print($0)
		}
		.onNext {
			XCTAssert($0 == 0)
		}
		.onNext {
			XCTAssert($0 == 1)
		}
		.onNext {
			XCTAssert($0 == 2)
		}
		.onNext {
			XCTAssert($0 == 10)
		}
		.onNext {
			XCTAssert($0 == 11)
		}
		.onNext {
			XCTAssert($0 == 12)
		}
		.onNext {
			XCTAssert($0 == 20)
		}
		.onNext {
			XCTAssert($0 == 21)
		}
		.onNext {
			XCTAssert($0 == 22)
		}
		.onNext {
			XCTAssert($0 == 3)
		}
		.onNext {
			XCTAssert($0 == 4)
		}
		.onNext {
			XCTAssert($0 == 5)
		}
		.onNext {
			XCTAssert($0 == 13)
		}
		.onNext {
			XCTAssert($0 == 14)
		}
		.onNext {
			XCTAssert($0 == 15)
		}
		.onNext {
			XCTAssert($0 == 23)
		}
		.onNext {
			XCTAssert($0 == 24)
		}
		.onNext {
			XCTAssert($0 == 25)
		}
		.onNext {
			XCTAssert($0 == 6)
		}
		.onNext {
			XCTAssert($0 == 7)
		}
		.onNext {
			XCTAssert($0 == 8)
		}
		.onNext {
			XCTAssert($0 == 16)
		}
		.onNext {
			XCTAssert($0 == 17)
		}
		.onNext {
			XCTAssert($0 == 18)
		}
		.onNext {
			XCTAssert($0 == 26)
		}
		.onNext {
			XCTAssert($0 == 27)
		}
		.onNext {
			XCTAssert($0 == 28)
		}
		.onNext {
			XCTAssert($0 == 9)
		}
		.onNext {
			XCTAssert($0 == 19)
		}
		.onNext {
			XCTAssert($0 == 29)
		}
		.run()
		
		var resultToCheck = [0, 0, 0, 1, 1, 1, 2, 2, 2, 0, 0 ,0, 1, 1, 1, 2, 2, 2, 0, 1, 2]
		let coroutine2 = SC<Int>.iterationsCoroutine(3, [SG<Int>.generator {
			try $0.yield(0)
			try $0.yield(0)
			try $0.yield(0)
			try $0.yield(0)
			try $0.yield(0)
			try $0.yield(0)
			return 0
		}, SG<Int>.generator {
			try $0.yield(1)
			try $0.yield(1)
			try $0.yield(1)
			try $0.yield(1)
			try $0.yield(1)
			try $0.yield(1)
			return 1
		}, SG<Int>.generator {
			try $0.yield(2)
			try $0.yield(2)
			try $0.yield(2)
			try $0.yield(2)
			try $0.yield(2)
			try $0.yield(2)
			return 2
		}]).onValue {
			XCTAssert(resultToCheck[0] == $0)
			resultToCheck.remove(at: 0)
		}
		coroutine2.run()
		XCTAssert(coroutine2.state == .finished)
	}

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
}
