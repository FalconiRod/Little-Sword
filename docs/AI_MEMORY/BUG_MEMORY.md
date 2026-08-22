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

## BUG-005 — Cliques não moviam o herói (v0.2.0..v0.2.9) — RESOLVIDO
Problema: clique esquerdo nunca disparava _handle_click; direito nunca cancelava.
Sintoma: clicar no chão não gera movimento; mira não cancela com botão direito.
Causa: no handler de release, _lmb_down = event.pressed sobrescrevia o flag
ANTES do elif testar — sempre falso. Mesmo padrão duplicado no RMB.
Arquivos: src/player/player_controller.gd (_unhandled_input).
Solução: capturar ar lmb_was := _lmb_down antes da atribuição e testar was.
Validação: novo harness ++ --clicktest injeta clique sintético e confere
movimento; atenção ao stretch canvas_items (push_input usa coords de JANELA:
enviar pos × get_final_transform()).
Status: RESOLVIDO em v0.2.10.
