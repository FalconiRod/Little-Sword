# Arquitetura — Little Sword

## Padrão
Autoloads (singletons) para sistemas; cena única `main.tscn` constrói tudo em
código no `_ready()`. Comunicação desacoplada via `EventBus` (sinais).

## Fluxo de turno
```
TurnManager._advance()
 ├─ herói → rola D6 movimento → PlayerController.on_turn_start (input liberado)
 └─ inimigo → EnemyAI.run_turn(unit) [async] → _advance()
PlayerController ação (atacar/skill/defender/item/passar)
 └─ CombatSystem.attack → D20 vs CA → dano → TurnManager.end_hero_turn()
```

## Módulos
| Arquivo | Responsabilidade |
|---|---|
| autoload/event_bus.gd | sinais globais (log, dados, turnos, morte, game over) |
| autoload/dice_manager.gd | D4–D20, notação "1d8+3", crítico natural 20 |
| autoload/turn_manager.gd | ordem fixa, rodadas, regra de movimento D6 |
| autoload/combat_system.gd | ataque/CA/crítico/falha crítica, Defender (+4 CA) |
| autoload/inventory_system.gd | equipar/remover/usar poção, bônus de CA/ataque |
| core/board_grid.gd | grid ASCII, ocupação, BFS alcançáveis + caminho |
| core/board_builder.gd | piso/paredes quebradas/tochas/baú/runas/névoa |
| core/camera_rig.gd | câmera iso, pan WASD, zoom scroll, shake |
| units/unit_base.gd | peça: stats, barra de vida 3D, salto célula a célula |
| units/unit_visuals.gd | miniaturas procedurais (knight/goblins/boss) |
| player/player_controller.gd | highlights (azul/vermelho/amarelo), clique-e-mova |
| enemy/enemy_ai.gd | perseguir/arqueiro mantém distância/boss com skills |
| ui/hud.gd | retrato+barras, botões, ordem, log, dados, boss bar, inventário |

## Mapa (ASCII)
13 colunas × 15 linhas; `#` parede, `.` piso, `T` tocha, `C` baú,
`r` runa, spawns: K cavaleiro, g goblin guerreiro (x2), a arqueiro, B boss.
Três salas ligadas por portas na coluna 6; névoa cobre sala 2 e 3.

## Decisão anti-travamento
Nenhum .tscn complexo hand-written: só main.tscn (raiz + script).
Impossível referenciar cena quebrada.
