//
//  SomeCoroutine.swift
//  SomeCoroutine
//
//  Created by Sergey Makeev on 13/08/2019.
//  Copyright © 2019 Sergey Makeev. All rights reserved.
//

import Foundation

public typealias SC = SomeCoroutine

public protocol CoroutineDelegate: class {
	typealias RoutineType = Any
	
	func coroutine(_ coroutine: SomeCoroutine<RoutineType>, stateChanged state: SomeCoroutineState)
	func coroutine(_ coroutine: SomeCoroutine<RoutineType>, routine: SG<RoutineType>, returned: RoutineType)
	func coroutine(_ coroutine: SomeCoroutine<RoutineType>, routineFinished routine: SG<RoutineType>)
	func coroutine(_ coroutine: SomeCoroutine<RoutineType>, routineCnagedFrom routine: SG<RoutineType>, to newRoutine: SG<RoutineType>)
	
}

public enum SomeCoroutineState: Int {
	case undefined
	case started
	case paused
	case pausing
	case stopped
	case stopping
	case finished
}


open class SomeCoroutine<Type> {
	
	fileprivate var _state: SomeCoroutineState = .undefined
	public internal(set) var state: SomeCoroutineState {
		get {
			return syncQueue.sync {
				return _state
			}
		}
		set {
			var onState: ((SomeCoroutineState)->Void)? = nil
			syncQueue.sync {
				_state = newValue
				onState = onStateAction
			}
			if let validQueue = queue {
				validQueue.async {
					self.delegate?.coroutine(self as! SC<Any>, stateChanged: newValue)
					onState?(newValue)
				}
			} else {
				delegate?.coroutine(self as! SC<Any>, stateChanged: newValue)
				onStateAction?(newValue)
			}
		}
	}
	fileprivate weak var _delegate: CoroutineDelegate? = nil
	public weak var delegate: CoroutineDelegate? {
		get {
			return syncQueue.sync {
				return _delegate
			}
		}
		
		set {
			freeDelegate()
			syncQueue.sync {
				_delegate = newValue
			}
		}
	}
	
	fileprivate var _iteration: Int = 0
	public internal(set) var iteration: Int {
		get {
			return syncQueue.sync {
				return _iteration
			}
		}
		
		set {
			syncQueue.sync {
				_iteration = newValue
			}
		}
	}
	
	fileprivate var _currentRoutineIndex: Int = 0
	public internal(set) var currentRoutineIndex: Int {
		get {
			return syncQueue.sync {
				return _currentRoutineIndex
			}
		}
		set {
			syncQueue.sync {
				_currentRoutineIndex = newValue
			}
		}
	}
	
	public var currentRoutine: SG<Type>? {
		let index = currentRoutineIndex
		return syncQueue.sync {
			return routines.count > 0 ? routines[index] : nil
		}
	}
	
	public var count: Int {
		return syncQueue.sync {
			return routines.count
		}
	}
	
	fileprivate var _operationStartTime:  TimeInterval = 0
	public internal(set) var operationStartTime:  TimeInterval {
		get {
			return syncQueue.sync {
				return _operationStartTime
			}
		}
		set {
			syncQueue.sync {
				_operationStartTime = newValue
			}
		}
	}
	
	fileprivate var _operationFinishTime: TimeInterval = 0
	public internal(set) var operationFinishTime: TimeInterval {
		get {
			return syncQueue.sync {
				return _operationFinishTime
			}
		}
		
		set {
			syncQueue.sync {
				_operationFinishTime = newValue
			}
		}
	}
	
	fileprivate var _routineStartTime:    TimeInterval = 0
	public internal(set) var routineStartTime:    TimeInterval {
		get {
			return syncQueue.sync {
				return _routineStartTime
			}
		}
		set {
			syncQueue.sync {
				_routineStartTime = newValue
			}
		}
	}
	
	fileprivate var _routineStartedOnIteration: Int = -1
	public internal(set) var routineStartedOnIteration: Int {
		get {
			return syncQueue.sync {
				return _routineStartedOnIteration
			}
		}
		set {
			syncQueue.sync {
				_routineStartedOnIteration = newValue
			}
		}
	}
	
	public init(_ routines:[SG<Type>]? = nil, delegate: CoroutineDelegate? = nil, queue:DispatchQueue? = nil, condition: @escaping (SomeCoroutine<Type>, SG<Type>, Any?) -> Bool ) {
		self.condition = condition
		self.routines  = routines ?? [SG<Type>]()
		self._delegate = delegate
		self.queue = queue
	}
	
	public static func timeCoroutine(_ interval: TimeInterval, delegate: CoroutineDelegate? = nil, queue:DispatchQueue? = nil, _ routines:[SG<Type>]? = nil) -> SomeCoroutine {
		return SomeCoroutine(routines, delegate: delegate, queue: queue, condition: { coroutine, routine, value in
			if coroutine.operationFinishTime - coroutine.routineStartTime >= interval {
				return true
			}
			return false
		})
	}
	
	public static func timeMapCoroutine(_ defaultInterval: TimeInterval, delegate: CoroutineDelegate? = nil, queue:DispatchQueue? = nil, map: [TimeInterval], _ routines:[SG<Type>]? = nil) -> SomeCoroutine {
		return SomeCoroutine(routines, delegate: delegate, queue: queue, condition: { coroutine, routine, value in
			var interval = defaultInterval
			if let index = coroutine.indexForRoutine(routine), index <= map.count {
				interval = map[index]
			}
			if coroutine.operationFinishTime - coroutine.routineStartTime >= interval {
				return true
			}
			return false
		})
	}
	
	public static func iterationsCoroutine(_ iterations: Int, delegate: CoroutineDelegate? = nil, queue:DispatchQueue? = nil, _ routines:[SG<Type>]? = nil) -> SomeCoroutine {
		return SomeCoroutine(routines, delegate: delegate, queue: queue, condition: { coroutine, routine, value in
			if coroutine.iteration - coroutine.routineStartedOnIteration >= iterations {
				return true
			}
			return false
		})
	}
	
	public static func iterationsMapCoroutine(_ defaultIterations: Int, delegate: CoroutineDelegate? = nil, queue:DispatchQueue? = nil, map: [Int], _ routines:[SG<Type>]? = nil) -> SomeCoroutine {
		return SomeCoroutine(routines, delegate: delegate, queue: queue, condition: { coroutine, routine, value in
			var iterations = defaultIterations
			if let index = coroutine.indexForRoutine(routine), index <= map.count {
				iterations = map[index]
			}
			if coroutine.iteration - coroutine.routineStartedOnIteration >= iterations {
				return true
			}
			return false
		})
	}
	
	deinit {
		stop()
	}
	
	public func indexForRoutine(_ routine: SG<Type>) -> Int? {
		return syncQueue.sync {
			var index = 0
			for r in routines {
				if routine === r {
					return index
				}
				index += 1
			}
			return nil
		}
	}
	
	fileprivate var onValueAction: ((Type)->Void)? = nil
	public func onValue(_ action: @escaping (Type)->Void) -> SomeCoroutine {
		syncQueue.sync {
			onValueAction = action
		}
		return self
	}
	
	//onCoroutine finished
	fileprivate var onFinishAction: (()->Void)? = nil
	public func onFinish(_ action: @escaping ()->Void) -> SomeCoroutine {
		syncQueue.sync {
			onFinishAction = action
		}
		return self
	}
	
	fileprivate var onNextActions: [(Type)->Void]? = nil
	public func onNext(_ action: @escaping (Type)->Void) -> SomeCoroutine {
		syncQueue.sync {
			if onNextActions == nil {
				onNextActions = [(Type)->Void]()
			}
			onNextActions?.append(action)
		}
		return self
	}
	
	fileprivate var onStateAction: ((SomeCoroutineState)->Void)? = nil
	public func onState(_ action: @escaping (SomeCoroutineState)->Void) -> SomeCoroutine {
		syncQueue.sync {
			onStateAction = action
		}
		return self
	}
	
	//Int - new routine index
	fileprivate var onContextChangedAction: ((Int)->Void)? = nil
	public func onContext(_ action: @escaping (Int)->Void) -> SomeCoroutine {
		syncQueue.sync {
			onContextChangedAction = action
		}
		return self
	}
	
	fileprivate var queue: DispatchQueue? = nil
	fileprivate var syncQueue: DispatchQueue = DispatchQueue(label: "Coroutine sync queue")
	
	private var retainedDelegate: Any?
	public func retainDelegate() {
		syncQueue.sync {
			retainedDelegate = delegate
		}
	}
	
	public func freeDelegate() {
		syncQueue.sync {
			retainedDelegate = nil
		}
	}
	
	public func add(_ routine: SG<Type>) -> SomeCoroutine {
		guard state != .stopped && state != .stopping else { return self}
		syncQueue.sync {
			routines.append(routine)
		}
		if state == .finished {
			state = .undefined
		}
		return self
	}
	
	
	private func _checkIfFinished() -> Bool {
		syncQueue.sync {
			routines = routines.filter({ generator -> Bool in
				return !generator.finished
			})
		}
		if count == 0 {
			onFinishAction?()
			return true
		}
		return false
	}
	private func _goToNextRoutine() {
		let oldRoutine = currentRoutine
		let oldCount = routines.count
		guard !_checkIfFinished() else {
			state = .finished
			return
		}
		let newCount = routines.count
		if newCount == oldCount {
			currentRoutineIndex += 1
		}
		if currentRoutineIndex >= newCount {
			currentRoutineIndex = 0
		}
		let newRoutine = currentRoutine
		delegate?.coroutine(self as! SC<Any>, routineCnagedFrom: oldRoutine as! SG<Any>, to: newRoutine as! SG<Any>)
		onContextChangedAction?(currentRoutineIndex)
		routineStartedOnIteration = iteration
		routineStartTime = Date().timeIntervalSince1970
	}
	
	private func _doIteration() {
		//guard state != .stopped && state != .stopping && state != .finished else { return }
		while state != .stopped && state != .stopping && state != .finished {
			if state == .pausing {
				state = .paused
				return
			}
			iteration += 1
			
			operationStartTime = Date().timeIntervalSince1970
			if let validCurrentRoutine = currentRoutine {
				if let value = currentRoutine?.next() {
					delegate?.coroutine(self as! SC<Any>, routine: validCurrentRoutine as! SG<Any>, returned: value)
					onValueAction?(value)
					var onNextAction: ((Type)->Void)? = nil
					syncQueue.sync {
						guard let onNextActions = onNextActions else { return }
						if onNextActions.count > 0 {
							onNextAction = onNextActions[0]
						}
					}
					onNextAction?(value)
					syncQueue.sync {
						if onNextActions?.count ?? 0 > 0 {
							_ = onNextActions?.remove(at: 0)
						}
					}
					operationFinishTime = Date().timeIntervalSince1970
					if condition(self, validCurrentRoutine, value) {
						_goToNextRoutine()
					}
				} else {
					//routine is finished
					delegate?.coroutine(self as! SC<Any>, routineFinished: validCurrentRoutine as! SG<Any>)
					_goToNextRoutine()
				}
			}
			//_doIteration()
		}
	}
	public func run() {
		guard state != .stopped && state != .stopping else { return }
		if state != .paused {
			routineStartedOnIteration = currentRoutineIndex
			routineStartTime = Date().timeIntervalSince1970
		}
		state = .started
		if let validQueue = queue {
			validQueue.async {
				self._doIteration()
			}
		} else {
			_doIteration()
		}
	}
	
	public func pause() {
		state = .pausing
	}
	
	public func stop() {
		state = .stopping
		syncQueue.sync {
			for routine in routines {
				routine.cancel()
			}
		}
		state = .stopped
	}
	
	//condition to interapt routine or not
	internal var condition: ((SomeCoroutine<Type>, SG<Type>, Any?) -> Bool)!
	internal var routines: [SG<Type>]!
	
}
