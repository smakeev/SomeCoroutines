//
//  SomeCoroutine.swift
//  SomeCoroutine
//
//  Created by Sergey Makeev on 13/08/2019.
//  Copyright © 2019 Sergey Makeev. All rights reserved.
//

import Foundation

public typealias SG = SomeGenerator

public struct SGVoid {
	//empty struct ot be returned from routine (Generator) if it should return nothing
}

public protocol YieldProviderProtocol {
	associatedtype GeneratorReturnType
	@discardableResult func yield(_ whatToReturn: GeneratorReturnType) -> Any?
	func subYield(_ generator: SomeGenerator<GeneratorReturnType>)
}


public class SomeGenerator<Type> {

	private enum WhoWorks: Int {
		case undefined
		case next
		case yield
	}

	public class YieldProvider<Type>: YieldProviderProtocol {
		public typealias GeneratorReturnType = Type

		internal weak var generator: SomeGenerator<Type>? = nil

		internal init(generator: SomeGenerator<Type>) {
			self.generator = generator
		}

		@discardableResult public func yield(_ whatToReturn: GeneratorReturnType) -> Any? {
			return generator?.internalYield(whatToReturn)
		}

		public func subYield(_ generator: SomeGenerator<GeneratorReturnType>) {
			while !generator.finished {
				if let result = generator.next() {
					self.yield(result)
				}
			}
		}
	}

	fileprivate var _finished: Bool = false
	public internal(set) var finished: Bool {
		get {
			return syncQueue.sync {
				return _finished
			}
		}

		set {
			syncQueue.sync {
				_finished = newValue
			}
		}
	}
	public internal(set) var current: Type? = nil

	public static func generator(_ builder: @escaping (YieldProvider<Type>) -> Type) -> SomeGenerator {
		let generator =  SomeGenerator<Type>()
		generator.yielder = YieldProvider<Type>(generator: generator)
		generator.yieldsBlock = builder
		return generator
	}

	public static func fromArray(_ array: [Type], additional: ((Type, Any) -> Type)? = nil) -> SomeGenerator {
		return SomeGenerator.comprehension({array[$0]}, iterations: array.count, additional: additional)
	}

	public static func comprehension(_ action: @escaping ((Int) -> Type?), iterations: Int, additional: ((Type, Any) -> Type)? = nil) -> SomeGenerator {
		let result = SomeGenerator<Type>.comprehension(action, isFinished: { (iteration, _) -> Bool in
			return iteration >= iterations - 1
		}, additional: additional)
		return result
	}

	public static func comprehension(_ action: @escaping ((Int) -> Type?), isFinished: @escaping ((Int, Type?)->Bool), additional: ((Type, Any) -> Type)? = nil) -> SomeGenerator {
		let result = SomeGenerator<Type>()
		result.isFinishedBlock = isFinished
		result.actionBuilder   = action
		result.additionalAction = additional
		return result
	}

	/*
		returns array from generator,
		generator produces values just the same way as using next method.
		At the end you will have an array of all elements and genrator will e finished.
		If you have a generator without finish element, don't use this method.
	*/
	public func toArray() -> Array<Type> {
		var array = [Type]()
		while !finished {
			if let value = next() {
				array.append(value)
			}
		}
		return array
	}

	/*
	Provides next generator's step.
	If generator is finished will return nil
	*/
	public func next() -> Type? {
		return next(nil)
	}

	/*
	Same as next, but with additional new value.
	Value is an additional argument wich will be provided to the generator on next iteration.
	If additionalAction has been provided it will be called with this value
	For range generator if no additional action step will be changed on new value.
	Note, step changed only for one iteration.
	Step should be in right direction. Otherwise generator will be finished.
	For comprehension: if additionalActian has been provided it will be called with this value.
	If no additional action - just ignore.
	For YIELD generator, current yield call will return this value.
	There is no additional action for YIELD generators.
	*/
	public func next(_ value: Any?) -> Type? {
		guard !finished else { return nil }
		additionalParam = value
		if rangeBuilder != nil ||
		   actionBuilder != nil {
				return internalNext()
		}

		if let yieldsBlock = yieldsBlock {
			if queue == nil {
				//first iteration
				queue = DispatchQueue(label: "yield queue for generator")
				guard let validQueue = queue else { return nil }
				validQueue.async { [weak self] in
					guard let validSelf = self else { return }
					//check condition
					while validSelf.who != .yield {
						validSelf.yieldIsReady = true
						if validSelf.who != .yield {
							validSelf.condition.wait()
						}
					}
					let lastValue = yieldsBlock(validSelf.yielder)
					validSelf.finished = true
					validSelf.lastYielded = lastValue
					//wakeUp generator thread
					while !validSelf.nextIsReady {}
					validSelf.who = .next
				}
			}
			//wait for yield
			while !yieldIsReady {}
			who = .yield
			while who != .next {
				nextIsReady = true
				if who != .next {
					condition.wait()
				}
			}
			if let lastValue = lastYielded {
				//current to lastYielded if lastYielded !nil
				current = lastValue
			}
			defer {
				lastYielded = nil
			}
			return lastYielded
		}

		return nil
	}

	internal var rangeBuilder:     ((_: SomeGenerator<Type>) -> Type?)? = nil
	internal var actionBuilder:    ((Int) -> Type?)?                    = nil
	internal var isFinishedBlock:  ((Int, Type?) -> Bool)?              = nil
	internal var additionalAction: ((Type, Any) -> Type)?               = nil
	internal var yieldsBlock:      ((YieldProvider<Type>) -> Type)?     = nil

	internal var iterationNumber: Int = 0
	internal var _additionalParam: Any? = nil
	internal var additionalParam: Any? {
		get {
			return syncQueue.sync {
				return _additionalParam
			}
		}

		set {
			syncQueue.sync {
				_additionalParam = newValue
			}
		}
	}

	private var yielder:     YieldProvider<Type>!
	private var queue:       DispatchQueue? = nil
	private var syncQueue:   DispatchQueue = DispatchQueue(label: "generator sync queue")
	private var _lastYielded: Type? = nil
	private var lastYielded: Type? {
		get {
			return syncQueue.sync(){
				return _lastYielded
			}
		}

		set {
			syncQueue.sync {
				_lastYielded = newValue
			}
		}
	}
	private var _yieldIsReady: Bool = false
	private var yieldIsReady: Bool {
		get {
			return syncQueue.sync {
				return _yieldIsReady
			}
		}

		set {
			syncQueue.sync {
				_yieldIsReady = newValue
				_nextIsReady = !newValue
			}
		}
	}
	private var _nextIsReady: Bool = false
	private var nextIsReady: Bool {
		get {
			return syncQueue.sync {
				return _nextIsReady
			}
		}

		set {
			syncQueue.sync {
				_nextIsReady = newValue
				_yieldIsReady = !newValue
			}
		}
	}
	private var condition: NSCondition = NSCondition()
	private var _who: WhoWorks = .undefined
	private var who: WhoWorks {
		get {
			return syncQueue.sync {
				return _who
			}
		}

		set {
			syncQueue.sync {
				_who = newValue
				condition.signal()
			}
		}
	}

	fileprivate func internalNext() -> Type? {
		guard !finished else { return nil }
		if let rangeGenerator = rangeBuilder {
			let value = rangeGenerator(self)
			if let validValue = value {
				current = validValue
				iterationNumber += 1
				return current
			} else {
				finished = true
			}
		} else if let actionGenerator = actionBuilder, let isFinished = isFinishedBlock {
			let result = actionGenerator(iterationNumber)
			if let validResult = result {
				if let additionalAction = additionalAction, let additionalParam = additionalParam {
					let newResult = additionalAction(validResult, additionalParam)
					current = newResult
				} else {
					current = validResult
				}
			}
			additionalParam = nil
			if isFinished(iterationNumber, result) {
				finished = true
			}
			iterationNumber += 1
			return current
		}

		return nil
	}

	fileprivate func internalYield(_ whatToReturn: Type) -> Any? {
		lastYielded = whatToReturn
		while !nextIsReady {}
		who = .next
		let yieldReturn = additionalParam

		while who != .yield {
			yieldIsReady = true
			if who != .yield {
				condition.wait()
			}
		}
		return yieldReturn
	}
}

public extension SomeGenerator where Type: Numeric & Comparable {

	static func range(_ target: Type, additional: ((Type, Any) -> Type)? = nil) -> SomeGenerator {
		return SomeGenerator.range(nil, target)
	}

	static func range(_ target: Type, step: Type, additional: ((Type, Any) -> Type)? = nil) -> SomeGenerator {
		return SomeGenerator.range(nil, target, step, additional: additional)
	}

	static func range(_ begin: Type?, _ target: Type, _ step: Type? = nil, additional: ((Type, Any) -> Type)? = nil) -> SomeGenerator {
		let result = SomeGenerator<Type>()
		result.additionalAction = additional
		result.rangeBuilder = { generator in
			let validBegin = generator.current ?? begin ?? Type.zero
			guard var validStep = step ?? Type(exactly: target > validBegin ? 1 : -1) else { return nil }
			//check for additional
			if let additionalParam = generator.additionalParam as? Type {
				if generator.additionalAction == nil {
					validStep = additionalParam
				}
			}
			guard validStep != 0 else { return nil }

			var nextInRange = generator.current == nil ? validBegin : validBegin + validStep
			if let additionalAction = generator.additionalAction, let additionalParam = generator.additionalParam {
				nextInRange = additionalAction(nextInRange, additionalParam)
			}
			generator.additionalParam = nil
			if validStep > 0 {
				if nextInRange >= target {
					return nil
				}
			}
			else {
				if nextInRange <= target {
					return nil
				}
			}
			return nextInRange
		}
		return result
	}
}

extension SomeGenerator: Sequence {
	public typealias Element = Type
	public typealias Iterator = GeneratorIterator<Type>

	public __consuming func makeIterator() -> Iterator {
		return GeneratorIterator<Type>(generator: self)
	}
}

public struct GeneratorIterator<Type>: IteratorProtocol {
	public typealias Element = Type

	var generator: SomeGenerator<Type>

	init(generator: SomeGenerator<Type>) {
		self.generator = generator
	}

	mutating public func next() -> Type? {
		return generator.internalNext()
	}
}

public class SomeCoroutine {

}
