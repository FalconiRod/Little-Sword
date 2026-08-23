# DIAGNÓSTICO — EDITOR DE MAPA (por que "nada acontece")

Data: 2026-08-23 · Estado: caçando o consumidor de mouse · Commits: fdc270b → c034b66 → 583fc9c

---

## 1. O QUE FOI IMPLEMENTADO (como funciona)

### Arquitetura real usada (não inventada)
O projeto NÃO usa `FloorTileDefinition`/`DungeonTileDefinition` como Resource.
O catálogo real é:

| Sistema | Arquivo | Papel |
|---|---|---|
| Catálogo de peças | `src/dungeon/tile_piece.gd` | `TilePiece.PROPS` (id → walkable/losb) + `build(id)` procedural |
| Grid/lógica | `src/core/board_grid.gd` | `tiles{Vector3i:{w,losb,elev}}`, `stair_links`, `set_tile()`, `add_stair_link()` |
| Mapa | `src/dungeon/environment_manager.gd` | `MAPS` (ASCII por andar), `LEGEND`, nós `Floor0..N`, `_validate_doors()` |
| Unidades | `src/scenes/main.gd` | `_spawn_units()` lê `env.spawns["K"/"M"/"W"/"g"/"a"/"B"]` |

### O editor (`src/editor/map_editor.gd`, autoload `MapEditor`)
- **F1** abre/fecha painel lateral (CanvasLayer layer=95, ScrollContainer à direita).
- **Biblioteca**: Pisos, Paredes/Colunas, Obstáculos, Props, Modelos GLB
  (scan recursivo de `res://src/assets`), Escadas, Spawns.
- **Thumbnails**: SubViewport 72×72 renderiza a peça uma vez → ícone do botão
  (mesmo princípio do retrato de personagem), fila lazy 1/frame com cache.
- **Transformação**: seleção por clique; rotação ±90° (Q/E ou botões);
  **escala uniforme** como controle principal; eixos X/Y/Z só atrás de
  checkbox avançado (evita distorção de modelos orgânicos); EXCLUIR.
- **Trocar chão**: override visual por célula em registro separado
  (`_floor_overrides`) preservando props da mesma célula; apagar restaura.
- **Escadas**: clique base + clique topo → `add_stair_link` + visuais;
  apagar um lado remove o par inteiro.
- **Persistência**: botão SALVAR → `%APPDATA%\Godot\app_userdata\
  Little Sword - Tactical Board RPG\map_edits_<mapa>.json`; recarrega no boot
  aplicando POR CIMA da geração (`MapEditor.begin_session(env)` no `main.gd`
  antes de `_spawn_units`). Edita-se a INSTÂNCIA; o catálogo nunca é mutado.
- **Pausa**: enquanto aberto, `PlayerController` ignora input do jogo,
  `TurnManager._wait_editor_unhold()` segura turnos/IA, câmera cede Q/E.

### Integração (3 arquivos)
- `project.godot`: autoload `MapEditor`.
- `main.gd`: `--editortest` (teste automatizado) + `begin_session(env)`.
- `tactical_camera.gd` / `turn_manager.gd`: gates de pausa/Q-E.

---

## 2. EVIDÊNCIAS COLETADAS (o que os testes mostraram)

| # | Experimento | Resultado | Conclusão |
|---|---|---|---|
| 1 | Teste headless `--editortest` (eventos sintéticos) | coloca/gira/escala/salva OK | Lógica interna correta |
| 2 | Log real da SUA sessão (`ed_debug.log`) | **zero** eventos `[EDITOR]` | Mouse nunca chega ao editor na janela real |
| 3 | F1 abre/fecha o painel pra você | funciona | Teclado CHEGA ao editor |
| 4 | Antes do fix 583fc9c: peça não registrava | `placed=0` mas `selected` mudava | `Vector3(Array)` não existe no Godot 4 → erro abortava metade da função (CORRIGIDO) |
| 5 | Scan GLB achava 0 modelos | lista vazia | pasta errada (`assets/models` vs `src/assets`) (CORRIGIDO: 20 GLBs) |

**Dedução-chave**: teclado passa pela fase *unhandled*; mouse passa ANTES pela
fase GUI (Controls). Algo consome o mouse nessa fase só na janela real — no
headless não existe esse consumidor.

## 3. HIPÓTESES RANQUEADAS

1. **Control invisível full-screen com MOUSE_FILTER_STOP** criado só quando a
   janela tem tamanho real (layout/âncoras computam diferente no headless).
   Suspeitos: fade/banner/popup do HUD, ou retângulo do próprio editor.
2. Ordem/fase de input diferente entre DisplayServer headless e Windows.
3. (Descartado) PlayerController/câmera consumindo — ambos sem consumo de LMB.
4. (Descartado) Código do editor não rodar — F1 prova que roda.

## 4. O QUE ESTOU TENTANDO AGORA (desta rodada)

1. **Nomear o culpado**: `_input()` agora loga `gui_get_hovered_control()`
   (o Control exato sob o mouse) no painel DBG e no console.
2. **Caminho alternativo à prova de GUI**: cliques são tratados em `_input()`
   (fase ANTERIOR à GUI). Se um fantasma estiver engolindo, o editor agora
   recebe antes dele. Cliques sobre o painel continuam indo pra UI normal.
3. **Fix preventivo de âncoras**: ScrollContainer agora tem altura positiva
   garantida (antes podia calcular rect inválido).
4. Log completo redirecionado para arquivo para eu ler sua sessão:
   `%TEMP%\opencode\ed_debug.log`.

## 5. PRÓXIMOS PASSOS SE AINDA FALHAR

- Ler o log: se aparecer `[EDITOR] mouse sobre UI: <caminho>`, o caminho
  denuncia o Control vilão → marco ele `IGNORE` quando o editor está aberto.
- Plano B: modo "captura total" — `get_viewport().set_disable_input(true)`
  seletivo nos CanvasLayers do HUD durante o editor.
- Plano C: mover o editor para dentro da cena principal (depois dos HUDs na
  árvore = prioridade máxima de input).

## 6. RESOLUCAO (2026-08-23, rodada final)

Log real (127 eventos): TODOS dentro do painel do editor; ZERO cliques no
tabuleiro; 8 cliques nos botoes de rotacao sem peca selecionada (= nada
visivel). O editor SEMPRE funcionou — faltava comunicar que a acao e
CLICAR NAS CASAS DO TABULEIRO, fora do painel.

Correcoes de UX:
- Barra STATUS amarela no topo do painel com feedback de cada acao
  ("OK: rubble colocado em (x,y,z). Q/E gira...").
- Botao "TESTE: colocar pedra ao lado do heroi" — prova de 1 clique,
  independente de picking.
- Mensagem de abertura instruindo os 2 passos.

Instrumentacao mantida: _input() captura antes da GUI + log de
gui_get_hovered_control() para futuros diagnósticos.
