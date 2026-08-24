# REGRAS DO PROJETO — Little Sword

> Todo PR/commit que adicionar `.glb` deve passar por esta vistoria. GLB fora do padrão trava o jogo (vide incidente 2026-08-24: `agua*.glb` 48 MB → MultiMesh 900× = OOM).

## REGRA 01 — PIPELINE OBRIGATÓRIO PARA TODO GLB (bloqueante)

Antes de entrar em `src/assets/**` todo modelo 3D novo **DEVE**:

1. **weld + simplify** (`gltf-transform weld` → `simplify --error 0.01`, nunca o padrão `0.0001`)
   - Meta: **< 5 MB** em disco, **< 50k vértices** / **< 100k tris**
   - Verificado em `2026-08-24`: `agua*.glb` 1,89M tris / 48 MB → 2,5-3,6 MB após simplify (mesh 45 MB → 0,5 MB)

2. **Texturas máx 1024×1024** (JPEG quality 85)
   - Antes: `4096×4096` → `89 MB` VRAM por textura (3× = 268 MB)
   - Depois: `1024×1024` → `5,5 MB` VRAM (16× economia)
   - Ferramenta: `tools/resize_manual.py` (Pillow) ou `gltf-transform resize --width 1024 --height 1024`
   - Resultado 2026-08-24: `agua*.glb` 2,5-3,6 MB → **0,52 / 0,73 / 0,74 MB**

3. **Sem compressão meshopt/quantization sem dequantize**
   - Se vier com `EXT_meshopt_compression` / `KHR_mesh_quantization` → converter para float32 (`copy + deq`)
   - Este Godot falha em silêncio (BUG-024)

4. **Normalizar por AABB** (pés `y=0`, centro XZ, topo em `y=0` para `tile_*.glb`)
   - `src/dungeon/environment_manager.gd:390` escala por `BoardGrid.TILE / span` (TILE=2,4)
   - Nunca ajustar à mão

5. **Validar**
   ```bash
   npx @gltf-transform/cli inspect src/assets/tilesets/seu_tile.glb  # vertices < 50k, textures <=1024
   ```

GLB que não passar é **rejeitado** — fica em `src/assets/terrenos/` ou `BACKUPS/` até otimizar.

## REGRA 02 — TILESETS UNIFICADOS (2026-08-24)

- Pasta única `src/assets/tilesets/` para battlemat e por-célula (`tile_*.glb`, `agua*.glb`)
- `bosque_30.tile_glb = res://src/assets/tilesets` (diretório, não arquivo fixo)
- Editor lista mesma biblioteca em **Battlemat (mapa inteiro)** e **Tiles de rio (por célula)** (`src/editor/map_editor.gd:258` `_glb_tiles()` / `:1562` `_mat_candidates()`)
- Troca `bosque ↔ água` a hora que quiser: F1 → Battlemat / Tiles de rio → RECARREGAR ASSETS

## REGRA 03 — GRID 2,4cm FIXO (2026-08-24)

- `src/core/board_grid.gd:6` `TILE=2,4` é a única verdade (célula `[col*2,4, col*2,4+2,4]`, centro `col*2,4+1,2`)
- Todo `world_pos` / `world_to_cell` / `map_bounds` / cursor / MultiMesh usa `BoardGrid.TILE`
- Estruturas em modo `SOBE` geram grid automático 2,4×2,4: `src/editor/map_editor.gd:405` `_top_fill()` faz raycast trimesh por casa coberta → `elev=round(h/0,55)` + `surface_h`, `neighbors()` só permite degrau ≤1 — personagem acha o melhor caminho sozinho

## REGRA 04 — BACKUP OBRIGATÓRIO (D:\PROJETOS)

Toda edição salva em `D:\PROJETOS\BACKUPS\BACKUP_LITTLE_SWORD_<DATA>` antes de commit.
