//
//  StringID.swift
//  Invasiones
//
//  Identifiers of the localised strings in data/strings_*.json.
//  Replaces the Res.STR_* integer constants (port of Res.cs).
//

/// A localised string. The raw value is its key in `data/strings_*.json`.
enum StringID: String, CaseIterable {
    case sdlInitFailed = "sdl_init_failed"
    case windowCaption = "window_caption"
    case fatalErrorCaption = "fatal_error_caption"
    case pressToContinue = "press_to_continue"
    case loading
    case next
    case back
    case youWon = "you_won"
    case youLost = "you_lost"
    case playAgain = "play_again"
    case objectives
    case accept
    case continueLabel = "continue"
    case menuMain = "menu_main"
    case menuContinue = "menu_continue"
    case menuNewGame = "menu_new_game"
    case menuLoadGame = "menu_load_game"
    case menuOptions = "menu_options"
    case menuCredits = "menu_credits"
    case menuHelp = "menu_help"
    case menuExit = "menu_exit"
    case menuSave = "menu_save"
    case menuRestart = "menu_restart"
    case buttonBack = "btn_back"
    case buttonGameMenu = "btn_game_menu"
    case gamePaused = "game_paused"
    case unit
    case resistancePoints = "resistance_points"
    case range
    case attackPoints = "attack_points"
    case visibility
    case aim
    case speed
    case exitConfirmation = "exit_confirmation"
    case yes
    case no
    case enterName = "enter_name"
    case done
    case creditsProgramming = "credits_programming"
    case creditsProgrammer1 = "credits_programmer_1"
    case creditsLevelDesign = "credits_level_design"
    case creditsLevelDesigner1 = "credits_level_designer_1"
    case objectiveBattle1 = "objective_battle_1_1"
    case objectiveBattle2 = "objective_battle_2_1"
    case objectiveBattle3 = "objective_battle_3_1"
    case objectiveBattle4 = "objective_battle_4_1"
    case battle1Title = "battle_1"
    case battle1Story = "battle_1_2"
    case battle1Objective = "battle_1_objective_3"
    case battle2Title = "battle_2"
    case battle2Story = "battle_2_2"
    case battle2Objective = "battle_2_objective_3"
    case battle3Title = "battle_3"
    case battle3Story = "battle_3_2"
    case battle3Objective = "battle_3_objective_3"
    case battle4Title = "battle_4"
    case battle4Story = "battle_4_2"
    case battle4Objective = "battle_4_objective_3"
    case aftermathTitle = "aftermath"
    case aftermath1 = "aftermath_1"
    case aftermath2 = "aftermath_2"
    case aftermath3 = "aftermath_3"
    case helpSelectTitle = "help_select_01"
    case helpSelectText = "help_select_02"
    case helpMoveTitle = "help_move_01"
    case helpMoveText = "help_move_02"
    case helpAttackTitle = "help_attack_01"
    case helpAttackText = "help_attack_02"
    case helpObjectiveTitle = "help_objective_01"
    case helpObjectiveText = "help_objective_02"
    case helpScrollTitle = "help_scroll_01"
    case helpScrollText = "help_scroll_02"
    case helpHudTitle = "help_hud_01"
    case helpHudText = "help_hud_02"
    case helpHealTitle = "help_heal_01"
    case helpHealText = "help_heal_02"
    case helpTipsTitle = "help_tips_01"
    case helpTipsText = "help_tips_02"
    case helpWinTitle = "help_win_01"
    case helpWinText = "help_win_02"
    case tipButton = "tip_00"
    case language
    case languageLabel = "language_label"
    case soundLabel = "sound_label"

    /// The intro pages shown before each battle, in order: three per battle
    /// (title, story, objective), then the epilogue.
    /// Page `p` of battle `b` is at `b * 3 + p`.
    static let introPages: [StringID] = [
        .battle1Title, .battle1Story, .battle1Objective,
        .battle2Title, .battle2Story, .battle2Objective,
        .battle3Title, .battle3Story, .battle3Objective,
        .battle4Title, .battle4Story, .battle4Objective,
        .aftermathTitle, .aftermath1, .aftermath2, .aftermath3,
    ]

    /// The objective reminder shown during play, by number of completed objectives.
    static let objectiveReminders: [StringID] = [
        .objectiveBattle1, .objectiveBattle2, .objectiveBattle3, .objectiveBattle4,
    ]

    /// The help screen pages, in the order of `HelpState.Substate`.
    static let helpPages: [(title: StringID, text: StringID)] = [
        (.helpSelectTitle, .helpSelectText),
        (.helpMoveTitle, .helpMoveText),
        (.helpAttackTitle, .helpAttackText),
        (.helpObjectiveTitle, .helpObjectiveText),
        (.helpScrollTitle, .helpScrollText),
        (.helpHudTitle, .helpHudText),
        (.helpHealTitle, .helpHealText),
        (.helpTipsTitle, .helpTipsText),
        (.helpWinTitle, .helpWinText),
    ]
}
