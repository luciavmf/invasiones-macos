//
//  UnitStatsTests.swift
//  InvasionesTests
//
//  Parsing unidades/*.csv into UnitStats.
//

import Testing
@testable import Invasiones

@MainActor
struct UnitStatsTests {

    @Test func parsesEveryKey() {
        let stats = UnitStats(csv: """
            Sprite;patricio
            Tipo;Alcance
            Velocidad;3
            Puntos_Resistencia;120
            Puntos_Ataque;25
            Visibilidad;11
            Punteria;6
            Alcance_Tiro;9
            Intervalo_Entre_Ataques;40
            Modo;Agresivo
            Nombre;Soldado Arg
            Avatar;unidades/patricio_avatar.png
            Puntos_De_Recuperacion;15
            Ticks_Entre_Recuparacion;45
            """)

        var expected = UnitStats()
        expected.sprite = .patricio
        expected.speed = 3
        expected.resistancePoints = 120
        expected.attackPoints = 25
        expected.visibility = 11
        expected.aim = 6
        expected.attackRange = 9
        expected.attackInterval = 40
        expected.name = "Soldado Arg"
        expected.avatar = "unidades/patricio_avatar.png"
        expected.recoveryPoints = 15
        expected.ticksPerRecovery = 45
        #expect(stats == expected)
    }

    @Test func missingOrInvalidValuesKeepTheDefaults() {
        let stats = UnitStats(csv: "Velocidad;fast\r\nPuntos_Ataque;\r\nNombre\r\n")

        #expect(stats == UnitStats())
    }

    @Test func anUnknownSpriteFallsBackToTheBritishOne() {
        #expect(UnitStats(csv: "Sprite;gaucho").sprite == .british)
    }

    /// A resource manager with the bundled unit files loaded.
    private func loadedResources() throws -> ResourceManager {
        let resources = ResourceManager()
        try resources.loadResourcePaths()
        resources.loadUnitTypes()
        return resources
    }

    @Test func theBundledFilesLoadForEveryType() throws {
        let resources = try loadedResources()

        let patricio = try #require(resources.unitStats[.patricio])
        #expect(patricio.sprite == .patricio)
        #expect(patricio.resistancePoints == 100)
        #expect(patricio.attackRange == 8)

        let british = try #require(resources.unitStats[.british])
        #expect(british.sprite == .british)
        #expect(british.resistancePoints == 50)
        #expect(british.attackInterval == 20)
    }

    @Test func aNewUnitStartsWithItsStatsAtFullHealth() {
        var stats = UnitStats()
        stats.resistancePoints = 50
        stats.attackRange = 8
        stats.speed = 3

        let unit = GameUnit(type: .british, stats: stats, sound: FakeSound())

        #expect(unit.health == 50)
        #expect(unit.resistancePoints == 50)
        #expect(unit.range == 8)
        #expect(unit.speed == (3, 3))
    }

    @Test func aUnitOfATypeTakesItsStatsFromTheResourcesItIsGiven() throws {
        let resources = try loadedResources()
        let grid = TestGrid(["....", "....", "....", "...."])
        let battlefield = Battlefield(map: grid, camera: Camera(x: 0, y: 0, height: 600))

        let unit = GameUnit(.british, battlefield: battlefield, sound: FakeSound(), resources: resources)

        #expect(unit.stats == resources.unitStats[.british])
        #expect(unit.resistancePoints == 50)
    }
}
