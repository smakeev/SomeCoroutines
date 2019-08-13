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

	public static func fromArray(_ array: [Type]) -> SomeGenerator {
		let result = SomeGenerator<Type>()
		result.arrayBuilder = array
		return result
	}

	public static func comprehension(_ action: @escaping ((Int) -> Type?), iterations: Int) -> SomeGenerator {
		let result = SomeGenerator<Type>.comprehension(action) { (iteration, _) -> Bool in
			return iteration >= iterations
		}
		return result
	}

	public static func comprehension(_ action: @escaping ((Int) -> Type?), isFinished: @escaping ((Int, Type?)->Bool)) -> SomeGenerator {
		let result = SomeGenerator<Type>()



		return result
	}

	internal var rangeBuilder: ((_: SomeGenerator<Type>) -> Type?)? = nil
	internal var arrayBuilder: [Type]? = nil

	private var iterationNumber: Int = 0
}

extension SomeGenerator where Type: Numeric & Comparable {

	public static func range(_ target: Type) -> SomeGenerator {
		return SomeGenerator.range(nil, target)
	}

	public static func range(_ target: Type, step: Type) -> SomeGenerator {
		return SomeGenerator.range(nil, target, step)
	}

	public static func range(_ begin: Type?, _ target: Type, _ step: Type? = nil) -> SomeGenerator {
		let result = SomeGenerator<Type>()
		result.rangeBuilder = { generator in
			let validBegin = generator.current ?? begin ?? Type.zero
			guard let validStep = step ?? Type(exactly: target > validBegin ? 1 : -1) else { return nil }
			guard validStep != 0 else { return nil }

			let nextInRange = generator.current == nil ? validBegin :validBegin + validStep

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

public class SomeCoroutine {

}
