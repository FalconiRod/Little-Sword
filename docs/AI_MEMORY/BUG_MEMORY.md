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

## BUG-014 - Alvo morto no voo do proj�til acessado ap�s free - RESOLVIDO
Problema: proj�til mata o alvo durante a anima��o; c�digo seguia chamando
animate_recoil/global_position em objeto liberado ('previously freed').
Arquivos: src/autoload/combat_system.gd.
Solucao: guardas is_instance_valid(target) apos os await points.
Status: RESOLVIDO (6/6 runs limpos).

## BUG-015 - Auto-cross de escada fazia unidade quicar de andar - RESOLVIDO
Problema: cruzar ao TERMINAR movimento + cruzar no INICIO do turno fazia
a IA subir e descer em loop na mesma escada.
Arquivos: unit_base.gd, player_controller.gd, enemy_ai.gd.
Solucao (ampliada em v0.6.1): o cross de INICIO de turno continua removido
(era a causa do quique). O cross AO TERMINAR movimento voltou, seguro:
dispara so se a unidade NAO chegou pelo salto pareado (compara o penultimo
passo do caminho com grid_pos) e custa 1 de movimento; sem movimento,
fica parada e cruza no turno seguinte andando ate a celula pareada.
Status: RESOLVIDO.

## BUG-016 - moves_left negativo quando auto-cross + custo do caminho - RESOLVIDO
Problema: player descontava o custo do caminho DEPOIS do await animate_move;
o auto-cross validava moves_left com orcamento ainda nao gasto e podia
deixar moves_left = -1 (ex.: 3 MP, caminho de 3 + cross).
Arquivos: player_controller.gd (_do_move).
Solucao: descontar dist ANTES do await (inimigos ja faziam nessa ordem).
Status: RESOLVIDO (STAIRTEST cenario 1 valida ML exato).

## BUG-017 - Clicar na escada cruzava sem querer - RESOLVIDO (v0.6.3 final)
Problema: o gatilho "cruzar ao terminar movimento" (v0.6.1) fazia clicar
na casa da escada como destino teleportar a unidade para o outro andar,
inclusive quando ela era corredor (stone_keep linha 7).
Arquivos: unit_base.gd, player_controller.gd, board_grid.gd.
Solucao FINAL (v0.6.3, spec do usuario): clicar NA escada cruza de fato
(era isso que ele queria), mas desembarca no primeiro grid LIVRE a frente
da escada de chegada (stair_landing), nao em cima dela; chegou pelo salto
pareado nao re-cruza; passar pelo corredor sem clicar nela nao cruza;
saida bloqueada avisa e a unidade espera na escada.
Status: RESOLVIDO (STAIRTEST 5/5; demos com sobe/desce nos dois modos).

## BUG-018 - Desembarque da escada falhava com saidas bloqueadas - RESOLVIDO
Problema: stair_landing so aceitava vizinhos ORTOGONAIS do par; no
stone_keep a coluna P (9,6,1) fica atras da escada de cima e qualquer
unidade nas laterais esgotava as saidas — "clicou na escada e disse que
estava ocupado acima", sem subir.
Arquivos: board_grid.gd (stair_landing), unit_base.gd (try_cross_stairs),
player_controller.gd.
Solucao: diagonais como reserva nas 8 direcoes; try_cross_stairs retorna
codigo (0/1/2) e o controller mostra motivo exato ("Sem movimento para
usar a escada" x "Saida da escada bloqueada acima/abaixo").
Status: RESOLVIDO (STAIRTEST 6/6, cenario 6 cobre bloqueio total).

## BUG-019 - Transicao de escada quebrada: andar ativo nunca sincronizado - RESOLVIDO
Problema: change_floor emitia unit_changed_floor, mas NINGUEM chamava
env.set_active_floor nem reposicionava a camera nesse evento. Apos cruzar:
heroi INVISIVEL (_apply_floor_visibility comparava z com o andar antigo),
andar antigo visivel/novo escondido ("piso flutuando abaixo do mapa"),
e a correcao so acontecia no clique de retrato/inicio de turno — o
"clique extra para completar a ida" relatado pelo usuario.
Arquivos: main.gd (novo _on_unit_changed_floor), unit_base.gd (fallback
para o par), environment_manager.gd.
Solucao: handler dedicado sincroniza visibilidade + fade + snap na hora;
travessia em UM clique garantida (8 saidas -> fallback em pe no par ->
so falha se par ocupado). Validacao de pareamento de escada na carga.
Status: RESOLVIDO (STAIRTEST 7/7; demos limpos).

## BUG-020 - Entulho atras da porta do 1 andar (stone_keep) - RESOLVIDO
Problema: 'o' em (6,4,1) ficava imediatamente atras da porta (6,5,1):
abrir a porta nao levava a lugar algum (a "pedra na porta do segundo
andar" relatada desde a v0.5.x).
Solucao: regra nova D14 (_validate_doors) detectou o caso na carga;
mapa corrigido ('o' -> ','). 4 mapas carregam sem warnings.

## DISCOVERY - Contrato de animate_move (2026-08-22)
EVIDENCIA: stairtest cenario 2 falhava porque o teste deixava grid_pos na
celula de ORIGEM; chamadores reais fazem BoardGrid.move_unit(dest=path[-1])
ANTES de animate_move(path, origem). O gatilho de fim de movimento le
grid_pos/ocupacao reais — estado inconsistente do teste produzia cross
aparentemente errado que era correto para o estado dado.
IMPACTO: qualquer teste/harness de movimento deve seguir o contrato:
move_unit primeiro, animate_move depois. Registrado tambem em RULES.

## DISCOVERY - TurnManager corre por cima de testes (2026-08-22)
EVIDENCIA: durante stairtest, _hero_turn/_enemy_turn seguiam rodando
(timers) e sobrescreviam moves_left manipulado pelo teste.
IMPACTO: testes que mexem em unidades devem ser curtos ou congelar o
TurnManager (game_ended=true temporario) para serem deterministicos.

## DISCOVERY - "Pedra na porta do 2 andar" era geometria v0.5.0 (2026-08-22)
EVIDENCIA: nos mapas v0.6.x nenhuma porta de andar superior esta
bloqueada: stone_keep portas (4,3,1) e (6,5,1) tem vizinhos livres e
nenhuma coluna P adjacente; tower/crypt nao tem portas no andar de cima.
IMPACTO: reclamacao do usuario referia-se aos degraus em sequencia da
v0.5.0 que ocupavam o corredor da porta — eliminada pelo S unico.

## DISCOVERY - StairsLink: par entra no BFS como vizinho (2026-08-22)
EVIDENCIA: reach inclui celulas do outro andar (mage reach=38 na torre);
custo da travessia = 1 passo, consistente com dist_to_goal (+1).
IMPACTO: clicar direto na celula do topo funciona; parar NA escada nao
cruza - inten��o explicita do jogador.
