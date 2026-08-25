# CURRENT_STATE — Little Sword REFEITO

## Fase atual: FASE 1 — CONCLUÍDA (aguardando confirmação)

### O que foi feito (Fase 1)
- Projeto novo Godot 4.7.2 `gl_compatibility`, `TILE=2.0` em `src/core/board_grid.gd` (único lugar).
- `FloorTheme` Resource (cor sólida por tema, `model_scene` futuro nulo).
- `VisualDefinition` base para troca primitiva->GLB futura.
- `FloorPiece` (StaticBody3D + BoxMesh 0.15 + BoxShape3D exato TILE x TILE, layer 1, metas walkable/blocks_los).
- `Board` gera 10x10 peças + bake raycast no physics_frame.
- `BoardGrid.bake_from_physics()` raycast por célula, clearance 1.8, fallback walkable se miss bounds zero.
- `MapEditor` stub com botão "Gerar Grid" + stats.
- `Main` com Board, luz, CameraPivot+SpringArm, HUD.
- `project.godot` com BoardGrid autoload único.

### Como testar
1. Abrir `D:\PROJETOS\_tools\godot472\Godot_v4.7.2-stable_win64.exe` -> Importar `project.godot`.
2. Play `src/scenes/main.tscn` — deve aparecer tabuleiro xadrez (verde/cinza) 10x10.
3. Console deve imprimir `BoardGrid bake: total=100 walkable=100 ...`
4. Clicar "Gerar Grid" deve re-bakear e atualizar stats.
5. `G` no teclado também regenera. Arrastar esquerdo orbita, roda zoom.
6. Headless: `Godot_v4.7.2-stable_win64_console.exe --headless --path "..." --quit` deve sair sem erro.

### Próximo passo
Aguardar confirmação do usuário para seguir para FASE 2 (paredes/portas/colunas/obstáculos).
