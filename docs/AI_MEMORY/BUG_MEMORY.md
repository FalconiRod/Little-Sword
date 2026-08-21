# BUG MEMORY

## BUG-001 — Inimigos nunca se moviam (RESOLVIDO)
DATA: 2026-08-21 | STATUS: RESOLVIDO (v0.1.2)
PROBLEMA: Inimigos ficavam parados; só atacavam quando o HERÓI chegava adjacente.
SINTOMA: Nenhuma linha "avança" no log; peças estáticas até a morte.
CAUSA: TurnManager._enemy_turn() não definia u.moves_left — inimigos jogavam
sempre com movimento 0 desde a v0.1.0. Mascarado pelo bot de demo, que caminha
até os inimigos.
ARQUIVOS: src/autoload/turn_manager.gd
SOLUÇÃO: `u.moves_left = u.move_max` no início do turno inimigo.
LIÇÃO: propriedades derivadas de estado por turno devem ser SEMPRE inicializadas
na entrada do turno (herói já fazia; inimigo foi esquecido). Testes de demo que
dependem de aproximação mútua escondem esse tipo de falha.

## BUG-002 — apply_to_unit órfão (RESOLVIDO)
DATA: 2026-08-21 | STATUS: RESOLVIDO (v0.1.1)
PROBLEMA: Anel de Defesa/espada não alteravam atributos.
CAUSA: InventorySystem.apply_to_unit existia mas ninguém chamava.
SOLUÇÃO: chamada no spawn do herói + no sinal inventory_changed.
