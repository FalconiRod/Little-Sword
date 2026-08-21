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
