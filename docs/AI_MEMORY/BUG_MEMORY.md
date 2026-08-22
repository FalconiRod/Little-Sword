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

## BUG-006 - grid_pos nao era gravado no grid novo (v0.4.0) - RESOLVIDO
Problema: reescrevi BoardGrid e place()/move_unit() perderam 'u.grid_pos = c'.
Sintoma: clicktest reportava posicao (0,0,0); unidades 'fantasmas'.
Arquivos: src/core/board_grid.gd.
Solucao: place/move_unit gravam grid_pos; validado demo/clicktest.
Status: RESOLVIDO em v0.4.0.

## BUG-007 - Chebyshev ignora o eixo Z (multi-andar) - RESOLVIDO
Problema: bot de demo e IA escolhiam alvo por chebyshev(x,y); inimigo no
andar de cima ficava 'a distancia zero' e o grupo nunca subia.
Sintoma: herois circulavam embaixo do arqueiro; rota=999 nos logs [BOT].
Arquivos: player_controller (_demo_play), enemy_ai (_hero/_step_toward/
_best_shooting_cell).
Solucao: distancias de rota via compute_reachable(goal, 99, ignore_units);
penalidade +4 por andar na escolha de alvo; melee exige mesmo andar.
Licao: em grid multi-andar, NUNCA usar chebyshev puro como proximidade.
Status: RESOLVIDO em v0.4.0.

## BUG-008 - Char 'S' virava parede e escadas inuteis (v0.4.0) - RESOLVIDO
Problema: LEGEND sem entrada para 'S'; _place_char caia no default
(set_tile(false,true)+parede). Links apontavam para celulas intransponiveis.
Sintoma: 'rota=999' mesmo com escada visivel; ninguem sobe de andar.
Arquivos: src/dungeon/environment_manager.gd.
Solucao: caso 'S' explicito colocando piso; 'L' e 'T' tambem ganharam piso.
Status: RESOLVIDO em v0.4.0.

## BUG-009 - Bot travava o turno apos abrir porta (v0.4.0) - RESOLVIDO
Problema: _demo_interact retornava sem encerrar a vez; jogo congelava.
Arquivos: src/player/player_controller.gd.
Solucao: do_pass() ao final da interacao.
Status: RESOLVIDO em v0.4.0.

## BUG-010 - HUD quebrava com heroi morto (v0.3.x, multi-heroi) - RESOLVIDO
Problema: _on_turn_started chamava update_vitals(knight) com referencia
liberada apos a morte ('previously freed').
Arquivos: src/ui/hud.gd.
Solucao: guards is_instance_valid; HUD adota o heroi ativo do turno;
refresh_buttons desabilita tudo se nao ha heroi vivo.
Status: RESOLVIDO em v0.4.0.

## DISCOVERY - class_name novo exige import (2026-08-22)
Novos scripts com class_name (EnvironmentManager etc.) dao 'Could not find
type' ate rodar: godot --headless --path . --import uma vez.

## BUG-011 - TILE nao declarado em tile_piece.gd (v0.5.0) - RESOLVIDO
Problema: step_piece usava TILE sem qualificar; const vive em BoardGrid.
Arquivos: src/dungeon/tile_piece.gd.
Solucao: referenciar BoardGrid.TILE.
Status: RESOLVIDO.

## BUG-012 - Off-by-one nas colunas 'S' dos mapas (v0.5.0) - RESOLVIDO
Problema: '#..P.S..#' poe S na coluna 5 (nao 4); escadas ficavam fora de
linha, _build_stairs as marcava como isoladas e ninguem subia.
Arquivos: environment_manager.gd (MAPS tower/stone_keep).
Solucao: recontar colunas caractere a caractere; diagnosticar com print
temporario de s_cells.
Status: RESOLVIDO.

## BUG-013 - neighbors() nunca cruzava andar (v0.5.0) - RESOLVIDO
Problema: offsets ortogonais tinham dz=0 fixo; o hop final degrau->landing
(andar de cima) nunca era candidato; rota=999 no bot.
Arquivos: src/core/board_grid.gd neighbors().
Solucao: testar dz in [0,1,-1] por offset; altura absoluta decide.
Status: RESOLVIDO.

## DISCOVERY - Autoria ASCII: contar colunas com indice (2026-08-22)
EVIDENCIA: BUG-012. Ao editar linhas de mapa, posicionar chars por INDICE
(0-based) e nao "quase visualmente"; largura da linha deve ficar constante.
IMPACTO: revisar diffs de MAPS sempre com contagem explicita.
