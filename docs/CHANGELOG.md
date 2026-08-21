# Changelog

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
