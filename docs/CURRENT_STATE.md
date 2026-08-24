# Estado Atual - 2026-08-24 - v0.9.3

## Status: TILE=2,4cm FIXO + TILESETS UNIFICADOS (troca a hora que quiser)

## O que funciona (validado headless + windowed RX580)
- 4 mapas modulares carregam sem warnings (portas/escadas validadas)
- Transicao de escada em 1 clique, estavel (stairtest 8/8)
- COMBATE: d20 vs CA, critico, dano por dados + regras taticas D15:
  * flanquear +2 ataque (lado oposto do alvo)
  * ataque de oportunidade ao sair da adjacencia (1x/inimigo/movimento)
  * cobertura +2 CA (obstaculo na direcao do golpe)
  * acao Dispersar [6] imune a oportunidade ate proximo turno
- TILE=2,4cm fixo em `src/core/board_grid.gd:6` (D17): célula = `[col*2.4, col*2.4+2.4]` centro `col*2.4+1.2`, shader e MultiMesh alinhados via `BoardGrid.TILE`
- TILESETS UNIFICADOS: `src/assets/tilesets/` contém `tile_bosque.glb` (0,71 MB) + `agua*.glb` otimizados **0,52/0,73/0,74 MB** (antes 48 MB cada) — **Battlemat (mapa inteiro)** e **Tiles de rio (por célula)** compartilham a MESMA biblioteca (`src/editor/map_editor.gd:258` `_glb_tiles` / `src/editor/map_editor.gd:1562` `_mat_candidates()`) — troque bosque↔água a hora que quiser, F1 → RECARREGAR ASSETS
- OTIMIZAÇÃO 2026-08-24: `agua*.glb` 1,89M tris → `simplify --error 0,01` + texturas `4096→1024` JPEG85 → `48 MB → 0,5-0,7 MB`, VRAM `89→5,5 MB` por textura (`tools/resize_manual.py`); pipeline agora é **REGRA 01** em `docs/RULES.md`
- PISO-FOLHA (D16): `bosque_30.tile_glb` agora aponta para `src/assets/tilesets/` (qualquer GLB lá serve; sem GLB cai na folha `piso bosque/bosque.jpg` 50×50 células)
- GRID AUTOMÁTICO 2,4×2,4 sobre estruturas: modo `SOBE` (`colina/eleva/lateral` auto) calcula `AABB` global + `elev = round(h/0.55)` por casa coberta (`src/editor/map_editor.gd:405` `_top_fill` com raycast + fallback `hh*fit*s`); `neighbors()` só permite degrau ≤1 — personagem procura melhor caminho e sobe degrau a degrau
- 4 mapas modulares + bosque_30 (30×30 seed 20260823) ok; STAIRTEST 8/8; COMBATTEST 4/4 (validar após TILE 2,4)

## Como jogar / validar
JOGAR_bosque.bat                                        # duplo clique!
godot --path . -- --map=bosque_30                       # PLAY mapa novo
godot --headless --path . --quit-after 900 -- --demo --map=bosque_30
godot --headless --path . --quit-after 1200 -- --combattest --map=tower
godot --headless --path . --quit-after 1200 -- --stairtest --map=tower
godot --headless --path . --quit-after 4000 -- --demo [--map=X]
godot --headless --path . --quit-after 1500 -- --clicktest / --skilltest

## Proximo passo recomendado
1. Feedback visual do usuario: azul de movimento agora casa com as casas
   impressas da folha (centro = col*2+1, bordas nas linhas)
2. Props GLB do usuario no lugar das arvores 'P'/rochas 'o' (com AABB
   ~1,8 unid) e miniaturas GLB para unidades
3. IA usando Dispersar ao recuar / flanqueando em dupla
4. Depois: audio e save

## Pendencias conhecidas
- Combate base<->topo entre celulas pareadas da escada: EXCLUIDO por
  decisao do usuario na D15 (revisitavel no futuro)
- Costura entre repeticoes da folha ainda nao inspecionada visualmente
- Grade impressa na arte deve coincidir com o shader - conferir em jogo

## Notas
- IMPORTANTE ao lancar por terminal: argumentos do jogo exigem '--'
  antes (ex.: `-- --map=bosque_30`); sem isso abre stone_keep silencioso
- JOGAR_bosque.bat ja correto (duplo clique abre o bosque)
