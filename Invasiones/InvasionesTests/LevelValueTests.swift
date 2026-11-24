//
//  LevelValueTests.swift
//  InvasionesTests
//
//  Plain value types: Command, Objective and Camera.
//

import Testing
@testable import Invasiones

@MainActor
struct CommandTests {

    @Test func storesKindAndTile() {
        let command = Command(.move, 3, 7)

        #expect(command.id == .move)
        #expect(command.point == (3, 7))
        #expect(command.width == 0)
        #expect(command.image == nil)
        #expect(command.animation == nil)
    }

    @Test func killCommandStoresItsZoneWidth() {
        let command = Command(.kill, 1, 2, 5)

        #expect(command.id == .kill)
        #expect(command.point == (1, 2))
        #expect(command.width == 5)
    }

    @Test func takeObjectWithMissingImageHasNoImage() {
        let command = Command(.takeObject, 4, 4, "imagenes/does_not_exist.png")

        #expect(command.id == .takeObject)
        #expect(command.image == nil)
    }
}

@MainActor
struct ObjectiveTests {

    @Test func emptyObjectiveHasNoNextCommand() {
        var objective = Objective()
        #expect(objective.nextCommand() == nil)
    }

    @Test func commandsComeOutLastInFirstOut() {
        var objective = Objective()
        objective.commands = [Command(.move, 0, 0), Command(.attack, 1, 1), Command(.heal, 2, 2)]

        #expect(objective.nextCommand()?.id == .heal)
        #expect(objective.nextCommand()?.id == .attack)
        #expect(objective.nextCommand()?.id == .move)
        #expect(objective.nextCommand() == nil)
        #expect(objective.commands.isEmpty)
    }
}

@MainActor
struct CameraTests {

    @Test func defaultsToFullScreenWidth() {
        let camera = Camera(x: 10, y: 20, height: 600)

        #expect(camera.x == 10)
        #expect(camera.y == 20)
        #expect(camera.startX == 0)
        #expect(camera.startY == 0)
        #expect(camera.width == ScreenSize.width)
        #expect(camera.height == 600)
    }

    @Test func screenCoordsInsideTheScreenAreKept() {
        let camera = Camera(x: 0, y: 0, height: 0)

        camera.setScreenCoords(x: 100, y: 50, w: 400, h: 300)

        #expect(camera.startX == 100)
        #expect(camera.startY == 50)
        #expect(camera.width == 400)
        #expect(camera.height == 300)
    }

    @Test func sizeIsClippedAtTheScreenEdge() {
        let camera = Camera(x: 0, y: 0, height: 0)

        camera.setScreenCoords(x: 900, y: 700, w: 400, h: 300)

        #expect(camera.width == ScreenSize.width - 900)
        #expect(camera.height == ScreenSize.height - 700)
    }

    @Test func negativeStartIsClampedToZero() {
        let camera = Camera(x: 0, y: 0, height: 0)

        camera.setScreenCoords(x: -10, y: -5, w: 100, h: 100)

        #expect(camera.startX == 0)
        #expect(camera.startY == 0)
    }
}
