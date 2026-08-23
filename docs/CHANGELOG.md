# Changelog

## v0.9.2 - 2026-08-23 - Grid sincronizado com as casas impressas (D17)
### Corrigido
- Area azul de movimento desalinhada meio quadrado das casas do tabuleiro:
  centro de celula passou de col*TILE para col*TILE+TILE/2 - agora as
  linhas impressas da folha e o shader de grade caem nas BORDAS das
  celulas (padrao FFT/Fire Emblem/BG3)
- Conversao raio->celula e amostragem de linha de visao usavam roundi()
  na convencao antiga; agora TODAS passam por BoardGrid.world_to_cell()
  (floori) / grid_to_world() - zero matematica avulsa fora do BoardGrid
### Alterado
- Malha da folha nasce em col*TILE (borda) em vez de col*TILE-TILE/2
- map_bounds() passa a bater exato com o span real das celulas
### Testes / Validacao
- stairtest 8/8; combattest 4/4; clicktest OK; demo bosque_30 limpa

## v0.9.1 - 2026-08-23 - Bosque 30x30 (usuario achou 50x50 grande)
### Alterado
- bosque_50 -> bosque_30; spawns do gerador ficam PROPORCIONAIS ao w/h
  (mesmo gerador serve de 20x20 a 70x50); combate inicia ja na rodada 1
- JOGAR_bosque.bat corrigido: faltava o separador '--' antes de --map
  (sem ele o Godot ignorava o argumento e abria stone_keep silencioso)

## v0.9.0 - 2026-08-23 - Piso-folha battle-grid + mapa 50x50 (D16)
### Adicionado
- Modo "sheet" no EnvironmentManager: pisos deixam de nascer por celula;
  UMA malha mesclada por andar recebe a folha do usuario (bosque.jpg)
  repetida em UV mundial alinhada a grade - 20x20 celulas por folha
  (400 casas, celula de 2,4 cm impressa), costuras sempre coincidem
- Shader de grade vetorial (next_pass) com antialias fwidth; linhas
  coincidem com as fronteiras das celulas logicas; opacity por mapa
- Mapa procedural bosque_50 (50x50, seed deterministica + flood-fill de
  conectividade dos spawns; arvores 'P' ~7%, rochas 'o', borda '#')
- Camera: limites de pan e zoom derivados de env.map_bounds() (mesas
  grandes recebem max_horizon/zoom_max escalados automaticamente)
- .gitignore: assets pesados do usuario (*.glb, *.jpg) ficam fora do Git
### Alterado
- _place_char registra celulas da folha (tudo menos abismo '~'); _piece
  suprime visuais de piso apenas quando sheet ativo (mapas antigos iguais)
### Testes / Validacao
- bosque_50: demo headless limpa (IA com rotas 20+ passos, reach=77);
  windowed RX580 exit 0 sem erros de shader
- Regressao verde: stairtest 8/8, combattest 4/4, clicktest OK,
  skilltest OK, stone_keep demo limpa

## v0.8.0 - 2026-08-22 - Regras taticas de combate (D15)
### Adicionado
- FLANQUEAR: +2 no ataque quando um aliado ocupa o lado oposto do alvo
  (corpo a corpo, mesmo andar; diagonais opostas contam)
- ATAQUE DE OPORTUNIDADE: sair da adjacencia de inimigo alertado provoca
  golpe gratis (1x por inimigo por movimento); Dispersar, escada e
  permanecer ao alcance nao provocam; dormindo nunca reage
- COBERTURA: +2 CA quando obstaculo (parede/pilar/entulho/porta fechada)
  fica entre atacante e alvo na direcao do golpe (cantos em diagonal)
- DISPERSAR: nova acao [6]/tecla 6 - consome a acao, imune a
  oportunidade ate o inicio do proximo turno
### Alterado
- animate_move executa ataques de oportunidade para herois E inimigos
- attack(): rotulo fornecido pelo chamador sempre aparece no dado
  ("Oportunidade" antes era trocado por "Ataque")
### Testes / Validacao
- NOVO --combattest: flanqueio, cobertura, oportunidade e dispersar 4/4 OK
- stairtest 8/8; clicktest OK; skilltest OK; demos x4 sem warnings/erros
## v0.7.1 - 2026-08-22 - Tween orfao do arco (pecas afundavam ao cruzar)
### Corrigido (BUG-021 - causa raiz achada por instrumentacao de frames)
- Sintoma: "clico na escada e as pecas vao para BAIXO do tabuleiro" -
  o animate_move tem um segundo tween por passo (arco do salto em
  position:y) que NAO era aguardado; no fluxo real (chegar na escada e
  cruzar no mesmo frame) ele ainda estava vivo e sobrescrevia o
  change_floor, puxando o heroi de volta ao andar antigo
- Fix: await th.finished em animate_move antes de retornar
- STAIRTEST: 7 -> 8 cenarios - asserts de Y em todos + s8 reproduz o
  fluxo real do jogo com janela de 0.5s (heroi E camera no andar certo)
### Validacao
- stairtest 8/8 OK; demos stone_keep/tower/crypt/house sem warnings;
  clicktest OK; skilltest OK
## v0.7.0 — 2026-08-22 — Causa raiz da transição + regra de porta desobstruída
### Corrigido (BUG-019 — causa raiz, não sintoma)
- `unit_changed_floor` nunca sincronizava `active_floor_index` nem a
  câmera: após cruzar, o herói ficava INVISÍVEL (`_apply_floor_visibility`
  comparava com o andar antigo), o andar anterior permanecia visível e o
  novo escondido — só se corrigia no clique de retrato/início de turno,
  o que parecia "precisar de um clique extra para completar a ida" e
  produzia o visual de "piso flutuando abaixo do mapa"
- Agora `_on_unit_changed_floor` (main.gd) aplica visibilidade na hora e,
  se for o herói, faz fade + troca de andar + snap da câmera no destino
### Alterado
- Travessia em UM clique garantida: esgotadas as 8 saídas do desembarque,
  a unidade chega EM PÉ na própria célula pareada; só falha (código 2)
  se até o par estiver ocupado (extremo raro). STAIRTEST agora 7/7
### Adicionado (PARTE 2 — regra de mapa)
- `_validate_doors()`: porta exige UM eixo (H ou V) com as duas células
  adjacentes caminháveis (o eixo de abertura); porta encostada em outra
  porta ou sem passagem dos dois lados → push_warning na carga do mapa;
  disfarçadas ('X') ficam fora da regra
- Validação do pareamento de escada (células existem e são caminháveis)
### Mapas
- stone_keep f1: entulho (6,4,1) removido — ficava ATRÁS da porta (6,5,1)
  e bloqueava a passagem (a "pedra na porta do segundo andar" relatada);
  os 4 mapas carregam sem nenhum warning

## v0.6.4 — 2026-08-22 — Desembarque mais tolerante + mensagens claras
### Corrigido
- "Cliquei na escada e disse que estava ocupado acima": o desembarque só
  aceitava os 4 vizinhos ortogonais — coluna `P` atrás da escada de cima
  (stone_keep) + qualquer unidade nas laterais derrubava a travessia
### Alterado
- `stair_landing` agora aceita DIAGONAIS como reserva (ordem fixa: 4
  ortogonais, depois 4 diagonais); só falha se TODAS as 8 saídas
  estiverem bloqueadas
- `try_cross_stairs` retorna código: 0 cruzou / 1 sem movimento /
  2 bloqueado; mensagens distintas ("Sem movimento para usar a escada" ×
  "Saída da escada bloqueada acima/abaixo")
### Testes
- STAIRTEST 6/6: novo cenário 6 (8 saídas ocupadas → código 2, unidade
  espera na escada; liberadas → cruza no re-click); demos/CLICKTEST/
  SKILLTEST OK

## v0.6.3 — 2026-08-22 — Clicar na escada cruza e desembarca à frente
### Alterado
- Clicar na casa da escada como destino: a unidade anda até ela e cruza
  AUTOMATICAMENTE para o outro andar (pedido do usuário), desembarcando no
  primeiro grid LIVRE À FRENTE da escada de chegada (`stair_landing`:
  vizinho ortogonal livre, ordem N/S/O/L) — não fica em cima da escada
- Chegar PELO salto pareado (destino já era outro andar) não re-cruza;
  passagem pelo corredor sem clicar na escada segue sem cruzar
- Saída bloqueada no destino: unidade fica na escada e avisa
  ("Saída da escada bloqueada no outro andar")
- Clique extra estando em pé na escada continua funcionando (re-cruza)
### Testes
- STAIRTEST 5/5 (cenário 4 agora valida o grid de desembarque exato);
  demos tower/stone_keep com subida/descida nos dois modos (salto do
  caminho e clique direto); CLICKTEST/SKILLTEST OK

## v0.6.2 — 2026-08-22 — Escada deixa de cruzar sozinha (BUG-017)
### Corrigido
- Clicar na casa da escada como destino jogava a unidade para o outro
  andar sem querer (relato: "clico na escada, desce abaixo do andar 1")
- Removido o gatilho de cruzar ao TERMINAR movimento (v0.6.1): pisar ou
  parar sobre a escada agora é como pisar em qualquer célula
### Alterado
- Travessia é sempre EXPLÍCITA: (a) caminho cujo passo executa o salto
  pareado (destino em outro andar); (b) clicar de novo na célula da
  escada estando EM PÉ nela (`try_cross_stairs`, custa 1 MP; sem MP,
  "Sem movimento ou escada ocupada")
- Prop espiral mais fino e baixo (62% da altura do andar): não lê mais
  como "pedra bloqueando" no corredor/porta do 1º andar
### Testes
- `--stairtest` reescrito: 5 cenários (parar não cruza; salto no meio do
  caminho cruza; sem dupla; cross explícito desce; sem MP é negado) OK
- Demos tower/stone_keep: travessias só com destino cross-floor;
  CLICKTEST/SKILLTEST OK

## v0.6.1 — 2026-08-22 — Travessia ao terminar o movimento (SUPERADA)
### Alterado
- `animate_move`: além do salto pareado executado no caminho, terminar o
  movimento SOBRE uma célula de escada agora também cruza (`_cross_stairs_now`),
  custando 1 de movimento; sem movimento sobrando, a unidade fica parada e
  cruza no turno seguinte andando até a célula pareada (vizinha no BFS)
- Guarda anti-duplo-disparo: quem chegou pelo salto pareado não re-cruza
  (comparação com o PENÚLTIMO passo do caminho, não com `prev` final)
- `player_controller._do_move`: custo do caminho é descontado ANTES do
  `await animate_move` (antes o auto-cross validava orçamento inflado e
  `moves_left` podia ficar negativo)
- Removido auto-cross de início de turno (continua — era o BUG-015)
### Adicionado
- Teste `--stairtest --map=tower` (4 cenários): cruza ao terminar com
  movimento; não cruza sem movimento; cruza no turno seguinte ao andar
  até o par; caminho terminando no par não dupla-cruza
- Validação: STAIRTEST 4/4 OK; demos stone_keep/tower/crypt/house sem
  erro, sem ML negativo, sem quique no mesmo tick; CLICKTEST/SKILLTEST OK

## v0.6.0 — 2026-08-22 — Escada como célula única de transição (StairsLink)
### Removido
- Modelo v0.5.0 de "degraus caminháveis" (alturas incrementais por célula,
  `_build_stairs`, `step_piece`, `height_at`/`set_height` em BoardGrid)
### Adicionado
- `BoardGrid.stair_links`: par bidirecional base<->topo (`add_stair_link`,
  `stair_pair`); mapas declaram `"stairs": [[base],[topo]]`
- `dist_to_goal()` em BoardGrid: mapa de distância cross-floor para IA/bot
  (BFS no andar do alvo + propagação pelos pares, +1 por travessia)
- Visual: prop ÚNICO por escada — coluna espiral na célula base
  (`stairs_prop`) + marcador âmbar no topo (`stairs_top`)
- Transição: quando o caminho executa o salto pareado, `animate_move`
  dispara `unit_changed_floor` naquele passo (ponto único; herói vê
  "Você muda de andar", inimigo "%s usa a escada")
### Alterado
- `neighbors()`: célula pareada entra como vizinha de custo normal
  (subir/descer custa entrar numa célula, sem ação especial)
- Células de escada são células normais: sem altura especial, pode
  ocupar/parar nelas; sem transições acidentais no meio do caminho
- Guarda `is_instance_valid(target)` em CombatSystem (BUG-014: alvo morto
  durante o voo do projétil era acessado após free)

## v0.5.0 — 2026-08-22 — Escadas retas por células reais (SUBSTITUÍDO)
### Removido
- `src/dungeon/stairs.gd` (DungeonStairs): modelo de "link/teleporte"
  entre andares eliminado; mapas não têm mais a chave `links`
### Adicionado
- Escada reta = sequência de células 'S' contíguas na linha/coluna do
  ASCII; cada degrau é célula REAL e pisável com altura incremental
  `FLOOR_H*(i+1)/(N+1)` (para no meio da escada é permitido)
- `TilePiece.step_piece(top_y, yaw)`: degrau com piso na altura exata
  da célula + riser maciço até a base (nada flutuando), alinhado ao
  centro da célula, rotação travada por eixo
- `_build_stairs()`/`_orient_stair()` em EnvironmentManager: agrupa
  'S', valida aproximação (mesmo andar) e destino (andar de cima),
  escolhe automaticamente o sentido de subida
### Alterado
- `BoardGrid`: campo `y` opcional por célula (altura absoluta real);
  `height_at()`/`world_pos()` usam o valor custom quando presente;
  `neighbors()` agora cruza andar quando célula adjacente (no plano)
  tem Δaltura ≤ STEP_MAX_DY (2.5) — é isso que conecta topo da escada
  ao andar de cima, sem teleporte; `add_link()` removido
- Mapas reautorados: stone_keep (escadas x=9 térreo→1º em 3 degraus e
  x=5 1º→2º), tower (coluna x=4), crypt (x=9 subindo -y)
- HUD/câmera/IA continuam funcionando sem mudança (change_floor só
  dispara ao sair do último degrau para a primeira célula do destino)

## v0.4.2 — 2026-08-22 — Câmera presa ao andar ativo + retratos clicáveis
- EventBus: `active_floor_changed(floor)` / `unit_changed_floor(unit, novo)`
- EnvironmentManager esconde andares não ativos (`set_active_floor`)
- Câmera foca o andar ativo (`focus_on`/`snap_focus`); trocar de andar
  usa fade preto (`HUD.fade_swap`): pan se mesmo andar, fade se outro
- Retratos da ordem de turno clicáveis (BG3-style): clique = vai até
  herói; badge ↑/↓ indica andar

## v0.4.1 — 2026-08-22 — Iluminação do dungeon kit
- `_setup_atmosphere()`: ambiente frio + lua direcional com sombra + névoa
- `_scatter_torches()`: até 30 tochas de parede com luz tremulante

## v0.4.0 — 2026-08-22 — Dungeon Kit: masmorra modular multi-andar
### Adicionado
- `src/dungeon/`: kit de peças 3D modular (estilo mesa D&D/FFT)
  - `tile_piece.gd` — catálogo PROPS (pisos, parede, pilar, entulho,
    ponte, baú, runas) com builders procedurais; ponto único de troca
    por assets GLB (Meshy) no futuro
  - `door.gd` — DungeonDoor (aberta/fechada/trancada/disfarçada),
    painel girando, trava/revela passagem secreta
  - `stairs.gd` — rampa de degraus ou espiral vertical, registra link
  - `environment_manager.gd` — mapas ASCII por andar (LEGEND de chars),
    4 mapas: stone_keep (3 andares), tower, house (porta trancada +
    alavanca), crypt (passagem secreta X + cofre)
- Grid multinível em BoardGrid: células Vector3i(x,y,andar), elevação
  por tile (plataformas), links de escada, LOS só no mesmo andar,
  BFS multinível (`compute_reachable(start, steps, ignore_units)`)
- Bônus de terreno alto (+1 ataque, mesma regra de mesa do D&D)
- Seleção de mapa por argumento: `++ --map=tower|house|crypt`
- Interação com portas/alavancas adjacente (clique) + bot de demo abre
  portas quando não há rota até o inimigo

### Alterado
- `main.gd` reescrito: EnvironmentManager substitui BoardBuilder;
  spawns vindos do mapa; boss bar revelado ao primeiro dano
- IA: alvo mais próximo com penalidade de andar (+4 por dz); perseguição
  e tiro usam distância de rota real (BFS); corpo-a-corpo exige mesmo andar
- Click/hover priorizam o andar do herói ativo (andares empilhados)
- HUD tolera herói morto (referências liberadas)

### Corrigido
- place/move_unit voltaram a gravar grid_pos na unidade (regressão)
- Tiles de escada 'S', alavanca 'L' e baú 'T' agora geram piso
- Linhas de mapa com largura irregular normalizadas; link da cripta

## v0.1.0 — 2026-08-21 — Vertical Slice inicial
### Adicionado
- Projeto Godot 4.7 (gl_compatibility), cena única main.tscn + orquestrador
- Sistemas autoload: EventBus, BoardGrid, DiceManager, TurnManager,
  CombatSystem, InventorySystem
- Dungeon ASCII 13×15: 3 salas, portas, tochas animadas, paredes quebradas,
  baú com loot, runas pulsantes, névoa por sala com reveal
- Miniaturas procedurais com base circular: Cavaleiro (olhos azuis, espada
  rúnica, capa vermelha), Goblin Guerreiro ×2, Goblin Arqueiro, Boss maior
  (chifres, olhos vermelhos, runas no peito)
- Combate D&D: D20+mod vs CA, crit nat20 dobra dados, falha nat1, Defender +4 CA
- Movimento tático: MP por D6 (1–2 = metade), BFS evitando peças, salto célula
- IA: perseguir/atacar; arqueiro mantém distância; boss com 3 habilidades
- HUD completo + inventário modal + barra do boss + tela fim de jogo + restart
- Modo `++ --demo` (bot autoplay) e captura `--write-movie`

### Arquivos
src/autoload/*.gd (5), src/core/*.gd (3), src/units/*.gd (3),
src/player/*.gd, src/enemy/*.gd, src/ui/hud.gd, src/scenes/main.*, project.godot

## v0.1.1 — 2026-08-21 — Percepção e balanceamento
### Adicionado
- Campo de visão por inimigo (goblin 6, arqueiro 7, boss 9) + linha de visão
  por raycast no grid (BoardGrid.has_line_of_sight)
- Estado 'alerted': inimigos mantém a guarda até AVISTAREM o herói ou serem
  atacados (aliados num raio de 2 também acordam); alertado = persegue para sempre
- Arqueiro só dispara com linha de visão livre
- Runas do chão: atacar sobre uma runa dá +2 de dano

### Corrigido
- InventorySystem.apply_to_unit nunca era chamado — Anel de Defesa (+2 CA) e
  Espada Ancestral (+1 atk) agora funcionam; reaplicado ao equipar/remover

### Balanceamento
- Cavaleiro: ataque +3 -> +5 (FOR +3 e proficiência +2, matemática D&D)
- Boss: 120 -> 90 PV; pesos de habilidade: normal 55%, Golpe Pesado 15%,
  Lâmina Sombria 15%, Escudo Sombrio 15% (só abaixo de metade da vida)
- Resultado: luta aperta mas justa — ciclo Defender/Golpe Poderoso + poções
  + runas vence por pouca margem; jogada errada perde

## v0.1.2 — 2026-08-21 — Movimento fixo inimigo + IA de aproximação
### Corrigido (BUG raiz)
- Inimigos jogavam com movimento 0 desde a v0.1.0 (_enemy_turn não definia
  moves_left). Agora cada inimigo usa seu valor ÚNICO FIXO por turno:
  goblin 4, arqueiro 3, boss 3 — sem rolagem, sem modificador.

### Mudado
- Nova IA de perseguição (_step_toward): dentro das casas alcançáveis no turno,
  escolhe sempre a que aproxima mais do herói (empate: menos passos). Progresso
  garantido mesmo com aliados bloqueando portas; impossível sobrepor peças.
- Arqueiro escolhe a melhor casa de tiro (dentro do alcance + linha de visão).

## v0.1.3 — 2026-08-21 — Câmera orbital
### Adicionado
- Órbita ao redor da mesa: Q/E (giro contínuo) e arrastar com botão do meio
  (ângulo livre). Pan agora é RELATIVO à direção da câmera (não inverte ao girar).
- Suavização por interpolação de alvo (yaw/zoom) — movimento de câmera fluido.
- Legenda de controles no canto inferior direito do HUD.
- Modo --orbit para demonstração (câmera gira sozinha).

## v0.1.4 — 2026-08-21 — Rotação primária pelo mouse
### Mudado
- Arrastar com o BOTÃO DIREITO agora gira a câmera (método principal).
  Clique direito SEM arrasto (limiar de 6px) continua cancelando a mira.
  Botão do meio e Q/E seguem como alternativas.

## v0.2.0 — 2026-08-21 — Câmera de mesa digital (órbita total)
### Reescrito
- camera_rig.gd: órbita esférica completa ao redor do pivô (yaw 360° +
  pitch 12°..85°), distância 4,2..34 com interpolação exponencial suave
  em todos os eixos.
### Adicionado
- Arrastar botão ESQUERDO gira a câmera; clique sem arrasto (limiar 6px)
  seleciona casas/miniaturas como antes. Botão do meio: pan "pegar a mesa".
- Colisão de câmera com paredes por amostragem no grid (sem física).
- Zoom multiplicativo suave; pan e WASD escalados pela distância.
### Mudado
- Padrão continua isométrico tático (yaw 45°, pitch 47°); ângulos baixos
  revelam vista cinematográfica rente à mesa.

## v0.2.1 — 2026-08-21 — Câmera mais suave
### Mudado
- Interpolação desacoplada por eixo: órbita k=5 (pesada), zoom k=6,
  pan k=8; posição final da câmera também interpolada (k=16), eliminando
  o pop ao colidir com paredes.
- Passo da roda menor (0.92) e arrasto levemente mais sensível (0.007).

## v0.2.2 — 2026-08-21 — TacticalCamera (arquitetura Pivot + SpringArm3D)
### Mudado
- Nova câmera 	actical_camera.gd (estilo BG3/Solasta): raiz = pan,
  Pivot = yaw/pitch suavizados (exp), SpringArm3D = zoom com colisão REAL
  (substitui amostragem manual de grid).
- Pan do teclado com aceleração/desaceleração (move_toward) — inércia real.
- Sensibilidade de rotação e limites de pitch (25°..75°) expostos como exports.
### Adicionado
- Colisores físicos nas paredes (StaticBody3D layer 2, exclusiva da mola).

## v0.2.3 — 2026-08-21 — Câmera AAA: target-interpolada + follow com lag
### Mudado
- Pan 100% por alvo interpolado (_pan_target -> lerp exp k=3.2 em
  _pan_position): nunca se escreve position direto. Deslize pesado BG3.
- Follow do herói com atraso natural (lag nasce da interpolação);
  religa a cada turno dele; pan manual (meio/WASD) desliga.

## v0.2.4 — 2026-08-21 — Esquema híbrido de rotação
### Adicionado
- Arrastar botão DIREITO gira a câmera pros lados (yaw). Esquerdo segue
  girando os dois eixos (padrão BG3). Clique direito sem arrasto
  continua cancelando a mira (limiar 6px).

## v0.2.5 — 2026-08-21 — Visão geral do mapa (tecla M)
### Adicionado
- Tecla M: enquadra a mesa inteira (pitch 72 graus, distancia calculada pelo
  tamanho do mapa, centrada) e M de novo volta ao enquadramento anterior.
  Tudo via alvos suavizados — transicao desliza sem cortes.
### Mudado
- zoom_max 22 -> 46 (agora alcanca o mapa todo); passo da roda escala com a
  distancia atual (1x..3x) para nao ficar lento no zoom-out.

## v0.2.6 — 2026-08-21 — Controles simplificados
### Removido
- Tecla M (visao geral). Ver o mapa todo agora e so rolar o zoom para fora
  (ate 46) e arrastar com as setas/WASD.
### Filosofia de controle
- Setas/WASD: mover a camera pelo mapa · Mouse: ajustar o angulo da visao.

## v0.2.7 — 2026-08-21 — Sensibilidade do mouse ajustavel em jogo
### Adicionado
- Teclas - e = : diminuem/aumentam a sensibilidade do mouse (40%..250%),
  com confirmacao no log. O arrasto de pan acompanha proporcionalmente.

## v0.2.8 — 2026-08-21 — Esquema de câmera igual ao tutorial BG3
### Mudado
- Botão do MEIO arrastando agora GIRA a câmera livremente (yaw+pitch),
  como no vídeo; pan pelo mouse removido (fica nas setas/WASD).
### Adicionado
- Tecla HOME recentra e trava o follow no herói com lerp (equivalente do
  attached_to_player + recenter_speed=10 do vídeo), com aviso no log.

## v0.2.9 — 2026-08-21 — Sensibilidade padrao reduzida
### Mudado
- rotation_sensitivity 0.12 -> 0.06 (metade). Regua do -/= recalibrada:
  100% = novo padrao; faixa continua 40%..250% via set_sensitivity.

## v0.2.10 — 2026-08-21 — Correção crítica de cliques + teste automatizado
### Corrigido
- BUG-005: clique esquerdo (mover/atacar/lootar) e clique direito (cancelar
  mira) mortos desde a v0.2.0 por flag sobrescrito antes do teste.
### Adicionado
- Harness --clicktest: injeta clique sintético numa casa alcançável e
  valida o movimento fim-a-fim (input -> raio -> grid -> tween).

## v0.2.11 — 2026-08-21 — Camera estavel: fim do travamento/teleporte
### Corrigido
- SpringArm sem colisao (mask 0): paredes nao teleportam nem travam mais a
  camera ao orbitar de perto.
### Adicionado
- Teto dinamico MAX_HORIZON (30u): em pitch baixo a distancia efetiva
  encolhe; camera nunca se estende para fora do tabuleiro.
- Piso rigido LEN_FLOOR (2.5) e guarda contra seguir unidade liberada.

## v0.2.12 — 2026-08-21 — Unidades viram para o alvo
### Adicionado
- Todo atacante (heroi, goblins, boss) gira a peca para o alvo antes do
  golpe, dentro de CombatSystem.attack (ponto unico, cobre habilidades).
- Em modo de mira, o cavaleiro ja encara o inimigo sob o cursor.

## v0.2.13 — 2026-08-21 — Polimento de combate: giro suave + investida
### Mudado
- face_towards agora interpola pelo menor caminho angular (tween 0.12s),
  sem a peca 'dar a volta' ao cruzar +-180 graus.
### Adicionado
- animate_lunge: investida curta (avanca 0.55u e retorna) sincronizada com
  a resolucao do golpe, para todos os atacantes via CombatSystem.

## v0.2.14 — 2026-08-21 — Feedback de impacto no combate
### Adicionado
- animate_recoil: alvo atingido recua na direcao oposta ao atacante.
- Faiscas procedurais (CPUParticles3D) no ponto do impacto; criticas soltam
  explosao maior em tom alaranjado.
- Texto flutuante MISS sobre o alvo quando o golpe nao conecta.

## v0.2.15 — 2026-08-21 — Ancoragem visual das pecas
### Adicionado
- Sombra fake circular (gradiente radial) sob cada miniatura; fica no chao
  mesmo com o bobbing, ancorando a peca na mesa.
- Anel dourado pulsante sob a unidade ativa no turno dela (EventBus
  turn_started), some ao morrer.

## v0.2.16 — 2026-08-21 — Clima de masmorra
### Adicionado
- Vinheta radial procedural nas bordas da tela (ignora mouse).
### Mudado
- Destaque de alcance de movimento mais sutil (alpha 0.34 -> 0.20); mira e
  interacao mantem o brilho original.

## v0.3.0 — 2026-08-21 — O grupo cresce: Maga Elara e Druida Rowan
### Adicionado
- Party de 3 herois jogaveis: cavaleiro, maga (alcance 4) e druida.
  O PlayerController comanda o heroi ativo do turno; camera segue qualquer
  heroi; IA inimiga passa a cacar o heroi vivo mais proximo.
- Habilidades por unidade (UnitDefs.SKILLS): Golpe Poderoso (3 mana),
  Misil Ardente da maga — projétil vermelho voador com faiscas no impacto
  (4 mana, 2d10+2), Fúria do Urso da druida — transforma a peca em urso
  durante o golpe (1d12+3) e ela segue na forma ate seu proximo turno.
- Miniaturas procedurais: maga (robe/chapeu/cajado com orbe vermelho),
  druida (manto verde/orbe verde) e urso quadrupede com garras.
- Teste --skilltest valida projétil + transformacao/reversao.
### Corrigido
- Harness --clicktest agora procura vizinho livre real (party ocupa as
  casas adjacentes ao spawn).
- Derrota so ocorre com TPK (todo o grupo abatido).

## v0.3.1 — 2026-08-21 — Linha de visao nos golpes
### Adicionado
- Todos os ataques (basico e habilidade) exigem linha de visao: paredes
  bloqueiam golpes, inclusive o Misil Ardente da maga.
- Mensagens de feedback quando o alvo esta sem visao/fora de alcance.
### Nota
- IA ja respeitava LOS (arqueiro reposiciona para conseguir angulo).

## v0.3.2 — 2026-08-21 — Cobertura e progressao
### Adicionado
- Marcador de cobertura: casas alcancaveis fora da linha de visao de todo
  inimigo em alerta ganham meio-tapete cinza ('protegido').
- Level up por abate: heroi que derrota um inimigo ganha nivel (+3 PV,
  +1 dano fixo); retrato mostra o nivel atual.

## Hotfix v0.4.1 — 2026-08-22 — Iluminacao do Dungeon Kit
### Corrigido
- Mapa totalmente escuro: EnvironmentManager nao criava luzes (o antigo
  BoardBuilder tinha as tochas). Adicionado _setup_atmosphere(): ambiente
  frio + 'lua' direcional com sombra + neblina sutil.
### Adicionado
- Tochas nas paredes com OmniLight tremulando (ate 30 por mapa).
- Screenshot de referencia: screenshots/v040_stone_keep.png

## v0.4.2 - 2026-08-22 - Camera por andar + selecao de grupo (estilo BG3)
### Adicionado
- EnvironmentManager.active_floor_index + set_active_floor(): mostra SOMENTE
  o andar ativo (pecas/tochas/portas/escadas em contenedores Floor#);
  dispara EventBus.active_floor_changed.
- EventBus.unit_changed_floor: ponto unico BoardUnit.change_floor() (e emissao
  ao fim de animate_move quando cruza escada).
- Retratos da ordem de turno clicaveis: clique foca a unidade; se estiver em
  outro andar, fade preto ~0.33s esconde a troca de laje e a camera reposiciona
  instantaneo no meio do fade (TacticalCamera.snap_focus); mesmo andar =
  pan suave (focus_on).
- Indicador por retrato ('^ 2' / 'v 1') quando a unidade nao esta no andar
  ativo; reage a active_floor_changed e unit_changed_floor (sem polling).
### Corrigido
- animate_move pulava com y fixo 0: heroi afundava no terreo visualmente ao
  subir/descer escadas (agora interpola ate wp.y do waypoint).
- Andares ficavam todos visiveis no boot (guard do set_active_floor(0)).
