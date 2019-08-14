//
//  SomeCoroutine.swift
//  SomeCoroutine
//
//  Created by Sergey Makeev on 13/08/2019.
//  Copyright © 2019 Sergey Makeev. All rights reserved.
//

public typealias SG = SomeGenerator

public class SomeGenerator<Type> {

	public internal(set) var finished: Bool = false
	public internal(set) var current: Type? = nil

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
			if let value = internalNext() {
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
		additionalParam = value
		if rangeBuilder != nil ||
		   actionBuilder != nil {
				return internalNext()
		}

		return nil
	}

	internal var rangeBuilder: ((_: SomeGenerator<Type>) -> Type?)? = nil
	internal var actionBuilder: ((Int) -> Type?)? = nil
	internal var isFinishedBlock: ((Int, Type?) -> Bool)? = nil
	internal var additionalAction: ((Type, Any) -> Type)? = nil

	internal var iterationNumber: Int = 0
	internal var additionalParam: Any? = nil

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

	fileprivate func yield(_ whatToReturn: Type) -> Any? {
		return nil
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
