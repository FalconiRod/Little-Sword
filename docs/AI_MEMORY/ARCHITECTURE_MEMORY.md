
### EDITOR DE MAPA v1 (2026-08-23)
- src/editor/map_editor.gd = autoload MapEditor. F1 abre/fecha painel lateral.
- Modos: Props (pillar/rubble/chest/runes/lever/torch), Modelos GLB (scan res://assets/models recursivo), Spawns (K/M/W/g/a/B), Apagar.
- Controles: clique coloca, direito apaga, R gira 45graus, roda do mouse escala GLB (0.3-4.0x), G troca modo.
- Persistencia: user://map_edits_<mapa>.json (%APPDATA%\Godot\app_userdata\Little Sword\) aplicado POR CIMA da geracao via MapEditor.begin_session(env) no main.gd antes de _spawn_units; overrides env.spawns[key]=[cell].
- Integracao: player_controller._unhandled_input retorna cedo se MapEditor.active; camera continua funcionando.
- v2 pendente: desenhar tabuleiro (add/remover casas/paredes) e atmosfera (luz/nevoa).

### EDITOR DE MAPA v2 (2026-08-23)
- v1 substituida por v2 no mesmo arquivo src/editor/map_editor.gd (autoload MapEditor).
- Biblioteca com categorias: Pisos (floor_stone/carpet/moss/bridge), Paredes/Colunas (wall_stone/pillar), Obstaculos (rubble), Props (chest/torch/lever), GLB (scan assets/models), Escada (par base+topo).
- Thumbnails via SubViewport 72x72 renderizado 1x por peca procedural (_render_icon_scene), cache em _icon_cache, fila lazy 1/frame.
- Modo Selecionar + painel de transformacao: rotacao +/-90graus (Q/E, camera cede Q/E quando editor ativo), escala UNIFORME slider 0.3-3.0 padrao, checkbox avancado libera eixos X/Y/Z independentes (distorce), botao EXCLUIR.
- Troca de piso por celula: overrides em _floor_overrides (registro separado de _placed) preserva props da mesma celula; erase restaura piso original.
- Escada: clique base -> clique topo (andares diferentes); cria stair_link + visuais stairs_prop/stairs_top registrados; apagar um lado remove link e par.
- Edicao e de INSTANCIA; catalogo TilePiece nunca mutado (ponto 5 da spec OK).
- Save roda env._validate_doors() (D14) avisando sem travar.
- Pausa logica: TurnManager._wait_editor_unhold() antes de IA/avancos; player input bloqueado; camera Q/E desviada.
- JSON user://map_edits_<mapa>.json schema v2: props[{id,c,rot,s,adv,struct?}], glbs[{p,c,rot,s,adv}], floors[{id,c}], stairs[[a,b]], spawns{K:[c]}; compat v1 (t->id, yaw->rot).
