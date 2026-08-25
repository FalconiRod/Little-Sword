# Little Sword — Tactical Board RPG REFEITO

> Recriação do zero (SEM GLB, só primitivas) — Godot 4.7.2 stable, `gl_compatibility`.

**Regra dourada:** nenhum `.glb` nesta etapa. Todo visual é `CapsuleMesh`/`BoxMesh`/`CylinderMesh`/`PlaneMesh` com cor sólida. GLB entrará depois via `Resource.model_scene` sem tocar lógica (arquitetura já preparada).

## Fase atual

**FASE 1 — CONCLUÍDA:** convenções `TILE=2.0`, `BoardGrid` único (grid_to_world/world_to_cell), chão `FloorPiece` (`BoxMesh` 0.15 + `StaticBody3D` exato), bake por raycast.

## Como rodar

```bat
"D:\PROJETOS\_tools\godot472\Godot_v4.7.2-stable_win64_console.exe" --path "D:\PROJETOS\Little Sword — Tactical Board RPG REFEITO" --main-pack "" 
REM ou abrir o Godot 4.7.2 e importar project.godot
```

Controles: arraste esquerdo = orbita, roda = zoom, `G` = Gerar Grid, `R` = recentra câmera.

## Estrutura

```
src/core/board_grid.gd      # ÚNICO lugar com TILE e conversão de coordenadas
src/resources/floor_theme.gd
src/resources/visual_definition.gd
src/board/floor_piece.gd/.tscn
src/board/board.gd
src/editor/map_editor.gd
src/scenes/main.tscn/.gd
```

## Convenções (imutáveis)

- `TILE = 2.0`, célula `(col,row,floor)` ocupa `[col*2, col*2+2]×[row*2,row*2+2]`, centro `col*TILE+TILE/2`.
- Raycast bake é fonte única de verdade; nenhum dado manual de grid fora do BoardGrid.
- `:=` tipado explicitamente onde Variant pode confundir.

## Próximas fases (seção 10 do PROMPT MESTRE)

FASE 2: paredes/portas/colunas/obstáculos primitivos + porta desobstruída
FASE 3: CharacterDefinition (6 fichas) com cápsulas coloridas
...
FASE 10: testes automatizados (--demo etc.)
