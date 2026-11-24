//
//  StateMachineTests.swift
//  InvasionesTests
//
//  State transitions with fake states that record their lifecycle calls.
//

import Testing
@testable import Invasiones

/// Records every lifecycle call into a log shared by all states of a test.
private final class FakeState: State {
    let stateMachine: StateMachine
    private let name: String
    private let log: CallLog

    init(_ name: String, machine: StateMachine, log: CallLog) {
        self.name = name
        self.stateMachine = machine
        self.log = log
    }

    func draw(_ video: Video) { log.calls.append("\(name).draw") }
    func update() { log.calls.append("\(name).update") }
    func start() { log.calls.append("\(name).start") }
    func exit() { log.calls.append("\(name).exit") }
}

private final class CallLog {
    var calls: [String] = []
}

@MainActor
struct StateMachineTests {

    private let machine = StateMachine()
    private let log = CallLog()

    init() {
        machine.addState(key: .logo, state: FakeState("logo", machine: machine, log: log))
        machine.addState(key: .mainMenu, state: FakeState("menu", machine: machine, log: log))
    }

    @Test func startsInvalid() {
        #expect(machine.currentState == .invalid)
        machine.update()
        #expect(log.calls.isEmpty)
    }

    @Test func setStateSwitchesImmediatelyWithoutLifecycleCalls() {
        machine.setState(.logo)

        #expect(machine.currentState == .logo)
        #expect(log.calls.isEmpty)

        machine.update()
        #expect(log.calls == ["logo.update"])
    }

    @Test func setNextStateWaitsForTheNextUpdate() {
        machine.setState(.logo)

        machine.setNextState(.mainMenu)
        #expect(machine.currentState == .logo)

        machine.update()
        #expect(machine.currentState == .mainMenu)
        #expect(log.calls == ["logo.exit", "menu.start", "menu.update"])
    }

    @Test func transitionHappensOnlyOnce() {
        machine.setState(.logo)
        machine.setNextState(.mainMenu)
        machine.update()
        log.calls.removeAll()

        machine.update()
        #expect(log.calls == ["menu.update"])
    }

    @Test func unknownKeyIsIgnored() {
        machine.setState(.logo)

        machine.setNextState(.credits)
        machine.update()

        #expect(machine.currentState == .logo)
        #expect(log.calls == ["logo.update"])
    }

    @Test func lastQueuedStateWins() {
        machine.setState(.logo)
        machine.addState(key: .options, state: FakeState("options", machine: machine, log: log))

        machine.setNextState(.mainMenu)
        machine.setNextState(.options)
        machine.update()

        #expect(machine.currentState == .options)
        #expect(log.calls == ["logo.exit", "options.start", "options.update"])
    }
}
