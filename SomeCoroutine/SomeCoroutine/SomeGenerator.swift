//
//  SomeGenerator.swift
//  SomeCoroutine
//
//  Created by Sergey Makeev on 17/08/2019.
//  Copyright © 2019 Sergey Makeev. All rights reserved.
//

import Foundation

public protocol YieldProviderProtocol {
	associatedtype GeneratorReturnType
	@discardableResult func yield(_ whatToReturn: GeneratorReturnType) throws -> Any?
	func subYield(_ generator: SG<GeneratorReturnType>) throws
}

public protocol SomeGeneratorProtocol {
	associatedtype GeneratorReturnType
	
	var current: GeneratorReturnType? {get}
	var finished: Bool {get}
	
	func toArray() -> Array<GeneratorReturnType>
	func next() -> GeneratorReturnType?
	func next(_ value: Any?) -> GeneratorReturnType?
	func cancel()
}

public class SG<Type> : SomeGeneratorProtocol {

	public typealias GeneratorReturnType = Type

	fileprivate enum Errors: Error {
		case noGenerator
		case generatorFinished
	}

	public class YieldProvider<Type>: YieldProviderProtocol {
		public typealias GeneratorReturnType = Type

		fileprivate weak var generator: SomeGenerator<Type>? = nil

		fileprivate init(generator: SomeGenerator<Type>?) {
			self.generator = generator
		}

		@discardableResult public func yield(_ whatToReturn: GeneratorReturnType) throws -> Any? {
			guard let validGen = generator else { throw Errors.noGenerator }
			if validGen.finished {
				throw Errors.generatorFinished
			}
			return try generator?.internalYield(whatToReturn)
		}

		public func subYield(_ generator: SG<GeneratorReturnType>) throws {
			guard let validGen = self.generator else { throw Errors.noGenerator }
			if validGen.finished {
				throw Errors.generatorFinished
			}
			while !generator.finished {
				if let result = generator.next(self.generator?.additionalParam) {
					self.generator?.additionalParam = nil
					try self.yield(result)
				}
			}
		}
	}

	deinit {
		cancel()
	}
	
	public func cancel() {
		self.generator.cancel()
	}
	
	public var finished: Bool {
		return self.generator.finished
	}
	
	public var current: Type? { return self.generator.current }

	public static func generator(_ builder: @escaping (YieldProvider<Type>) throws -> Type) -> SG {
		let SELF = SG<Type>()
		let generator =  SomeGenerator<Type>.generator(builder)
		SELF.generator = generator
		return SELF
	}

	public static func fromArray(_ array: [Type], additional: ((Type, Any) -> Type)? = nil) -> SG {
		let SELF = SG<Type>()
		let generator = SomeGenerator.comprehension({array[$0]}, iterations: array.count, additional: additional)
		SELF.generator = generator
		return SELF
	}

	public static func comprehension(_ action: @escaping ((Int) -> Type?), iterations: Int, additional: ((Type, Any) -> Type)? = nil) -> SG {
		let SELF = SG<Type>()
		let generator = SomeGenerator.comprehension(action, iterations: iterations, additional: additional)
		SELF.generator = generator
		return SELF
	}

	public static func comprehension(_ action: @escaping ((Int) -> Type?), isFinished: @escaping ((Int, Type?)->Bool), additional: ((Type, Any) -> Type)? = nil) -> SG {
		let SELF = SG<Type>()
		let generator = SomeGenerator.comprehension(action, isFinished: isFinished, additional: additional)
		SELF.generator = generator
		return SELF
	}

	public func toArray() -> Array<Type> {
		return generator.toArray()
	}

	public func next() -> Type? {
		return generator.next()
	}

	public func next(_ value: Any?) -> Type? {
		return generator.next(value)
	}

	fileprivate var generator: SomeGenerator<Type>!
	
	private init() {}
	
	#if DEBUG
	internal var deinitPromise: (() -> Void)? {
		get {
			return generator.deinitPromise
		}
		
		set {
			generator.deinitPromise = newValue
		}
	}
	#endif
}

public extension SG where Type: Numeric & Comparable {

	static func range(_ target: Type, additional: ((Type, Any) -> Type)? = nil) -> SG {
		let generator = SomeGenerator.range(nil, target)
		let SELF = SG<Type>()
		SELF.generator = generator
		return SELF
	}

	static func range(_ target: Type, step: Type, additional: ((Type, Any) -> Type)? = nil) -> SG {
		let SELF = SG<Type>()
		let generator = SomeGenerator.range(nil, target, step, additional: additional)
		SELF.generator = generator
		return SELF
	}

	static func range(_ begin: Type?, _ target: Type, _ step: Type? = nil, additional: ((Type, Any) -> Type)? = nil) -> SG {
		let SELF = SG<Type>()
		let generator = SomeGenerator.range(begin, target, step, additional: additional)
		SELF.generator = generator
		return SELF
	}
}

public struct SGVoid {
	//empty struct ot be returned from routine (Generator) if it should return nothing
}

fileprivate class SomeGenerator<Type> {

	private enum WhoWorks: Int {
		case undefined
		case next
		case yield
	}


	deinit {
		cancel()
	}

	public func cancel() {
		//we need to release the queue thread and not do any yields
		//set generator to be finished
		finished = true
		//wake up yield thread to be sure it will be finished.
		who = .yield

		while yieldIsSleeping {
			condition.signal()
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

	public static func generator(_ builder: @escaping (SG<Type>.YieldProvider<Type>) throws -> Type) -> SomeGenerator {
		let generator =  SomeGenerator<Type>()
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
					//check condition
					#if DEBUG
					let promise = self?.deinitPromise
					#endif
					while (self?.who ?? .yield) != .yield {
						self?.yieldIsReady = true
					}
					do {
						let yielder = SG<Type>.YieldProvider<Type>(generator: self)
						let lastValue = try yieldsBlock(yielder)
						self?.lastYielded = lastValue
						self?.finished = true
						//wakeUp generator thread
						while !(self?.nextIsReady ?? false) {}
						self?.who = .next
					} catch {
						//generator has been finished.
						#if DEBUG
					
						print("!!!! Catch in yields")
						if let promise = promise {
							promise()
						}
						#endif
					}

				}
			}
			//wait for yield
			while !yieldIsReady {
				if yieldIsSleeping {
					condition.signal()
				}
			}
			who = .yield
			while who != .next {
				nextIsReady = true
				if yieldIsSleeping {
					condition.signal()
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
	internal var yieldsBlock:      ((SG<Type>.YieldProvider<Type>) throws -> Type)?     = nil

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
				guard !_finished else { return }
				_lastYielded = newValue
			}
		}
	}
	private var _yieldIsSleeping: Bool = false
	private var yieldIsSleeping: Bool {
		get {
			return syncQueue.sync {
				return _yieldIsSleeping
			}
		}

		set {
			syncQueue.sync {
				_yieldIsSleeping = newValue
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
				if _who == .yield {
					condition.signal()
				}
			}
		}
	}

	#if DEBUG
	internal var deinitPromise: (() -> Void)?
	#endif

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
			return result != nil ? current : nil
		}

		return nil
	}

	fileprivate func internalYield(_ whatToReturn: Type) throws -> Any? {
		if finished {
			throw SG<Type>.Errors.generatorFinished
		}
		lastYielded = whatToReturn
		while !nextIsReady {}
		who = .next
		let yieldReturn = additionalParam

		while who != .yield {
			yieldIsReady = true
			if who != .yield {
				yieldIsSleeping = true
				condition.wait()
			}
		}
		yieldIsSleeping = false
		if finished {
			throw SG<Type>.Errors.generatorFinished
		}
		return yieldReturn
	}
}

fileprivate extension SomeGenerator where Type: Numeric & Comparable {

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

extension SG: Sequence {
	public typealias Element = Type
	public typealias Iterator = GeneratorIterator<Type>

	public __consuming func makeIterator() -> Iterator {
		return GeneratorIterator<Type>(generator: self)
	}
}

public struct GeneratorIterator<Type>: IteratorProtocol {
	public typealias Element = Type

	var generator: SG<Type>

	init(generator: SG<Type>) {
		self.generator = generator
	}

	mutating public func next() -> Type? {
		return generator.next()
	}
}
