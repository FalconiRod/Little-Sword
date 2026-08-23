# LITTLE SWORD — TACTICAL BOARD RPG
## Documento Estrutural e História Completa (v0.1.0 → v0.9.8)
Atualizado em: 2026-08-23 · Fontes: Git (62 commits), código real, docs/AI_MEMORY/

---

## 1. IDENTIDADE DO PROJETO

| Item | Valor |
|---|---|
| Nome | Little Sword — Tactical Board RPG |
| Engine | Godot 4.7.2 stable (`D:\PROJETOS\_tools\godot472\`) — NUNCA usar 4.7.1 (causava crash) |
| Linguagem | GDScript |
| Renderer | `gl_compatibility` (OpenGL 3.3 — escolhido pela RX 580 da máquina) |
| Local | `D:\PROJETOS\Little sword` (regra de disco: sempre D:\PROJETOS) |
| Backups | `D:\PROJETOS\BACKUPS\` (ex.: `little_sword_glb_orig` = modelos originais) |
| Controle | Git (main). Assets .glb/.jpg fora do git via .gitignore |

### Conceito do produto
RPG tático por turnos inspirado em **mesa física de RPG**: tabuleiro com grade
(impressa em folha A3 pelo usuário ou gerada no jogo), miniaturas 3D, câmera
estilo BG3, combate D20 com regras de mesa (flanqueio, cobertura, ataque de
oportunidade), masmorras multi-andar com escadas reais e um bosque procedural.

---

## 2. ESTRUTURA DE PASTAS

```
Little sword/
├── project.godot            (gl_compatibility, main scene)
├── JOGAR_bosque.bat         (atalho duplo-clique: abre o bosque_30)
├── src/
│   ├── autoload/            EventBus, DiceManager, TurnManager,
│   │                        CombatSystem, InventorySystem
│   ├── dungeon/             environment_manager.gd (MAPS, pisos, props,
│   │                        sheet-folha, MultiMesh tiles, gerador proc),
│   │                        board_grid.gd, tile_piece.gd
│   ├── units/               unit_base.gd (BoardUnit), unit_defs.gd,
│   │                        unit_visuals.gd
│   ├── player/              player_controller.gd (input, mira, ações)
│   ├── enemy/               enemy_ai.gd (bot determinístico)
│   ├── scenes/              main.gd (boot + harness de testes)
│   └── ui/                  hud.gd (retratos, vitals, botões, log)
├── src/assets/              GLBs das miniaturas/tile + folha bosque.jpg
│   │                        (fora do git; importados pelo Godot)
│   ├── piso bosque/         tile_bosque.glb (chão casa-a-casa) + bosque.jpg
│   ├── maga/  goblins/      modelos das peças
│   └── urso transformaçao/  modelo do urso
├── docs/                    PROJECT_CONTEXT, ARCHITECTURE, DECISIONS (D14–D17),
│   │                        CHANGELOG, CURRENT_STATE, HANDOFF, FEATURES,
│   │                        PROMPT_MESTRE
└── docs/AI_MEMORY/          BUG_MEMORY, SOLUTIONS_MEMORY, SESSION_MEMORY,
                             TASK_MEMORY, CORE_MEMORY, CHANGELOG
```

---

## 3. LINHA DO TEMPO COMPLETA (por versão)

### Fase 1 — Núcleo jogável (v0.1.x)
- **v0.1.0** Vertical slice: RPG tático de tabuleiro jogável (knight, movimento
  por células, ataque básico, HUD).
- **v0.1.1** Campo de visão + alerta de inimigo, linha de visão (LOS),
  balanceamento do boss, fix do inventário (poções).
- **v0.1.2** Movimento dos inimigos funcional + perseguição determinística.
- **v0.1.3–v0.1.4** Câmera orbital Q/E + botão do meio; rotação por arrasto
  do direito. Hint no HUD.

### Fase 2 — Câmera estilo BG3 (v0.2.x — 17 versões!)
- **v0.2.0–v0.2.2** Orbit completa (arrasto esquerdo, pitch, zoom cinemático,
  colisão por grid) → suavização por eixo → `TacticalCamera` com
  Pivot+SpringArm3D e colisão física das paredes (layer 2).
- **v0.2.3–v0.2.5** Camera-lag/follow do herói (BG3); rotação híbrida
  (direito = yaw, esquerdo = órbita); visão geral na tecla M; zoom até 46.
- **v0.2.6–v0.2.9** Remove tecla M (setas movem mapa, mouse ajusta ângulo);
  sensibilidade ajustável em jogo (-/=); esquema BG3 (meio gira visão, Home
  recentra no herói); sensibilidade padrão reduzida à metade.
- **v0.2.10** Fix BUG-005 (cliques mortos) + criação do harness `--clicktest`.
- **v0.2.11** Mola sem colisão + teto dinâmico de alcance (câmera estável).
- **v0.2.12–v0.2.16** Polimento de combate: atacante vira para o alvo +
  pré-mira no hover; giro angular suave + investida (lunge); recuo do alvo +
  faiscas procedurais + MISS flutuante; sombra fake nas peças + anel pulsante
  da unidade ativa; vinheta de masmorra; destaque de movimento sutil.

### Fase 3 — Party e regras (v0.3.x)
- **v0.3.0** Maga Elara (míssil flamejante vermelho) e Druida Rowan
  (transformação em urso).
- **v0.3.1** LOS obrigatória em golpes (paredes bloqueiam).
- **v0.3.2** Marcador de cobertura cinza + level-up por abate.

### Fase 4 — Dungeon Kit (v0.4.x–v0.5.0)
- **v0.4.0** Masmorra modular multi-andar: escadas, portas, 4 mapas ASCII,
  células Vector3i.
- **v0.4.1** Iluminação: ambiente frio + "lua" direcional com sombra + tochas
  tremulando.
- **v0.4.2** Câmera restrita ao andar ativo + retratos clicáveis com fade.
- **v0.5.0** Escadas retas por células reais (depois substituídas).

### Fase 5 — StairsLink (v0.6.x)
- **v0.6.0** Escada como PAR de células ligadas (StairsLink) + freed-target nos
  guardas.
- **v0.6.1** Cruzar ao terminar movimento sobre a escada + stairtest
  (4 cenários).
- **v0.6.2** BUG-017: escada NÃO cruza sozinha — travessia explícita;
  prop visual mais fino.
- **v0.6.3** Clicar na escada cruza e desembarca no primeiro grid à frente.
- **v0.6.4** BUG-018: desembarque aceita diagonais + motivo exato na mensagem.

### Fase 6 — Transição de andar (v0.7.x)
- **v0.7.0** Causa raiz da transição (sync andar/câmera via evento) +
  regra de porta desobstruída (**D14**).
- **v0.7.1** **BUG-021**: tween órfão do arco de salto sobrescrevia
  change_floor e afundava as peças → await do arco em animate_move;
  stairtest expandido para 8 cenários.

### Fase 7 — Regras táticas de mesa (v0.8.0)
- **v0.8.0** **D15**: flanquear +2 ataque, ataque de oportunidade, cobertura
  +2 CA, ação Dispersar; combattest 4/4.

### Fase 8 — Battle-grid físico (v0.9.x — ATUAL)
- **v0.9.0** **D16** piso-folha battle-grid: a folha IMPRESSA do usuário vira o
  chão (mesh única SurfaceTool, UVs em espaço-mundo, shader de grade
  `GRID_SHADER_CODE`, cull disabled); mapa PROCEDURAL `bosque` (gerador de
  linhas com flood-fill de conectividade, retries de seed, spawns
  proporcionais a w×h); câmera auto-escala (`max_horizon =
  max(30, max_dim*0.55)`, zoom_max ≥ max_dim*0.85) via `map_bounds()`.
- **(v0.9.1)** Ajuste: mapa renomeado `bosque_30` (50×50 era grande demais);
  spawns proporcionais consolidados; `JOGAR_bosque.bat`.
- **v0.9.2** **D17** ALINHAMENTO: convenção canônica — célula (col,row) ocupa
  `[col*2,(col+2)]×[row*2,(row+2)]`, centro `= col*TILE + TILE/2`;
  conversões ÚNICAS `grid_to_world()` / `world_to_cell()` no BoardGrid
  (proibido floor/round de TILE fora delas). Movimento azul agora casa com as
  linhas impressas.
- **v0.9.3** Folha v2 da arte (bosque.jpg 5908²px, grade impressa 50×50):
  `cells_per_sheet 20→50`; mapa 30×30 cabe numa folha só (zero costuras).
- **v0.9.4** Sistema tile-GLB: UM modelo de UMA casa instanciado célula a
  célula via **MultiMesh** (1 draw call por andar), escalado por AABB
  (largura/profundidade → TILE=2.0), topo em y=0, centrado na célula;
  ativado por `"tile_glb": <pasta>` no map def; fallback automático p/ folha.
- **v0.9.5** **BUG-024**: Godot 4.7.2 desta máquina NÃO importa
  EXT_meshopt_compression/KHR_mesh_quantization (falha silenciosa,
  `valid=false`). Tile do usuário convertido p/ float32 puro
  (gltf-transform `copy` + script `deq.cjs`) → tile funcionando.
- **v0.9.6** Cavaleiro recebe miniatura GLB real (Ranger Hi3D renomeado p/
  ASCII `_glb_piece`: normaliza pés y=0, centro, altura alvo).
- **v0.9.7** **SOL-012** TODAS as peças viram miniaturas GLB reais (maga,
  druida, urso, goblin guerreiro/arqueiro, hobgoblin=boss) com alturas por
  peça (heróis 1.55 / goblins 1.10 / urso 1.30 / boss 1.95); círculos
  brilhantes (_base) REMOVIDOS; **retopologia geral**
  (weld+simplify: tile 987k→7k tris; personagens ~19k) resolveu travamento
  geral do jogo.
- **v0.9.8** **SOL-013** Freeze na transformação em urso: texturas
  8192²(~358MB VRAM cada!) → redimensionadas ≤1024px (script sharp); todos os
  GLBs <1MB; guard anti-AABB-degenerado no carregador.

---

## 4. SISTEMAS CENTRAIS (como funciona hoje)

### BoardGrid (board_grid.gd)
- `TILE = 2.0`, `FLOOR_H = 7.0`, `ELEV_H = 0.55`. Células `Vector3i(col,row,floor)`.
- **D17 (canônico)**: `grid_to_world(cell)` = centro `col*2+1`; 
  `world_to_cell(p)` = `floori`. TODA conversão passa por elas.
- BFS `compute_reachable` (movimento), `has_line_of_sight` (LOS por amostragem),
  `occupied` (dicionário célula→unidade), `stair_links`, `special` ('r' runas).

### EnvironmentManager (environment_manager.gd)
- Dicionário `MAPS`: mapas ASCII clássicos (stone_keep default + 3) e
  `bosque_30` procedural (`{"proc": {w,h,seed}}`, seed 20260823).
- Chão do bosque em 3 estágios de prioridade: `tile_glb` (MultiMesh) →
  `sheet` (folha texturizada com shader de grade) → piso procedural.
- Props: paredes/pilares/tochas/portas/baú/'~' fosso/'r' runas; árvores/rochas
  como miniaturas EM CIMA do piso; `map_bounds()` alimenta a câmera.

### Unidades (unit_base/unit_defs/unit_visuals)
- Stats por id em `UnitDefs`; skills: maga "Míssil Ardente" (2d10+2,
  projétil), druida "Fúria do Urso" (1d12+3, `transform`), knight "Golpe
  Poderoso".
- `set_visual_id` / `revert_visual` (urso volta a humana no início do turno).
- Visuais: `_glb_piece()` normaliza qualquer GLB (pés no chão, centrado,
  altura-alvo) com fallback procedural; alturas por peça.

### Combate (CombatSystem + D15)
- d20+bonus vs CA; crítico natural dobra dados; fumble; terreno alto +1;
  flanco +2 (célula oposta); cobertura +2 CA (cantos bloqueados); ataque de
  oportunidade; Defender +4 CA; Dispersar (sem oportunidade).
- Feedback: dice roll no HUD, faiscas, shake, textos flutuantes, investida/recuo.

### Turnos e IA
- `TurnManager` alterna heróis→inimigos; `EnemyAI` determinístico: estados
  vigília/alerta, perseguição por caminho, best-cell por alcance, logs [BOT].

### Câmera (TacticalCamera)
- Pivot+SpringArm (layer 2), lag/follow, arrasto esquerdo órbita, direito yaw,
  Home recentra, zoom estendido 46, teto dinâmico por tamanho do mapa,
  auto-setup via `map_bounds().grow(TILE)`.

### HUD
- Retratos clicáveis com fade, vitals, barra de mana, botões contextuais
  (Atacar/Habilidade/Item/Defender/Dispersar/Passar Vez), log colorido,
  mira com destaque vermelho nos alvos válidos.

---

## 5. PIPELINE DE ASSETS (aprendizado crítico)

1. Modelos vindos de IA (Hi3D/Tripo) chegam com problemas:
   - **BUG-024**: meshopt + quantização que este Godot não suporta
     (`valid=false` silencioso). Fix: `copy` + `deq.cjs` → float32 limpo.
   - **Poligoniais demais** (1–2 milhões tris). Fix: `weld` + `simplify`
     com `--error 0.01` (padrão 0.0001 quase não reduz!). **SOL-012**.
   - **Texturas gigantes** (até 8192² = 358MB VRAM cada). Fix: resize
     programático sharp ≤1024px (CLI tem bug de colourspace). **SOL-013**.
2. Chão por MultiMesh: 900 casas = 1 draw call; escala uniforme por AABB;
   topo em y=0; centro na célula (D17).
3. `.gitignore`: `src/assets/**/*.glb(+.import)`, `*.jpg` — assets ficam fora
   do git; originais preservados em `D:\PROJETOS\BACKUPS\little_sword_glb_orig`.
4. Lançamento: SEMPRE com separador `--`
   (`--path ... -- --map=bosque_30`); sem ele o Godot engole argumentos e
   abre stone_keep silenciosamente. Atalho: `JOGAR_bosque.bat`.

---

## 6. VALIDAÇÃO (harness embutido no main.gd)

| Comando | Cobertura | Status |
|---|---|---|
| `--demo` | boot + bots jogam sozinhos | OK |
| `--clicktest` | clique→célula→movimento (BUG-005) | OK |
| `--skilltest` | míssil + FORMA SELVAGEM + reversão | OK (pós-v0.9.8) |
| `--stairtest` | 8 cenários de escada/transição | OK |
| `--combattest` | flanco/oportunidade/cobertura/dispersar | OK 4/4 |

Binário de testes: `Godot_v4.7.2-stable_win64_console.exe` (headless ou janela).
Import após trocar assets: `--headless --import` (obrigatório).

---

## 7. DECISÕES DE ARQUITETURA (resumo das registradas)

- **D14** Porta desobstruída: travessia exige célula livre além da porta.
- **D15** Regras táticas de mesa (flanco/cobertura/oportunidade/dispersar).
- **D16** Piso-folha battle-grid: arte do usuário É o chão.
- **D17** Convenção canônica de coordenadas (centro=col*2+1; conversões únicas
  no BoardGrid; nada de floor/round de TILE fora delas).
- Grid por-mapa (GRID_SIZE não é global) — mapas variam de tamanho.
- Assets pesados fora do git; código+docs versionados.
- Miniaturas: normalização por AABB (nunca escalar à mão).

## 8. BUGS MARCANTES (detalhes em BUG_MEMORY)

- **BUG-005** cliques mortos (raycast/ordem de input) → clicktest.
- **BUG-017** escada cruzava sozinha ao pisar → travessia explícita.
- **BUG-018** desembarque só ortogonal → diagonais aceitas + mensagem com motivo.
- **BUG-021** tween órfão do salto afundava peças ao trocar de andar → await
  do arco (lição: TODO tween que move peças precisa ser aguardado/encadeado).
- **BUG-024** GLB meshopt/quantização falham em silêncio neste build do Godot.

## 9. ESTADO ATUAL (v0.9.8 — commit 2f98fc5)

Funcionando: jogo completo jogável no bosque_30 com tabuleiro GLB casa-a-casa,
todas as peças são miniaturas 3D reais retopologizadas (<1MB cada), combate
tático completo com regras de mesa, escadas multi-andar nos mapas clássicos,
câmera BG3 auto-ajustável, transformação do druida fluida.

Pendências conhecidas / próximos passos sugeridos:
1. 6 miniaturas `tripo_*_meshopt.glb` ainda precisam do tratamento BUG-024
   quando quiserem usá-las (mesmo pipeline já documentado).
2. Confirmar com o usuário: alinhamento fino das peças vs casas, facing do
   ranger (se de costas, girar 180° no holder), gosto visual das alturas.
3. Opção de desligar a linha de grade do shader se a arte do tile já tiver
   sulcos (evitar linha dupla).
4. Áudio: nenhum som implementado até agora.
5. Menu principal/save-system: inexistentes (boot direto na masmorra).
6. Mapa procedural com tile_glb em outros biomas (desert/neve) — sistema pronto.

---
*Gerado sob demanda do usuário ("fale tudo que fizemos do início até agora").
Consulte docs/DECISIONS.md e docs/AI_MEMORY/* para o detalhamento vivo.*
