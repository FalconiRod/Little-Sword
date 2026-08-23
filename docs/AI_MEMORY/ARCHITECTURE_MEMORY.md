
### EDITOR DE MAPA v1 (2026-08-23)
- src/editor/map_editor.gd = autoload MapEditor. F1 abre/fecha painel lateral.
- Modos: Props (pillar/rubble/chest/runes/lever/torch), Modelos GLB (scan res://assets/models recursivo), Spawns (K/M/W/g/a/B), Apagar.
- Controles: clique coloca, direito apaga, R gira 45graus, roda do mouse escala GLB (0.3-4.0x), G troca modo.
- Persistencia: user://map_edits_<mapa>.json (%APPDATA%\Godot\app_userdata\Little Sword\) aplicado POR CIMA da geracao via MapEditor.begin_session(env) no main.gd antes de _spawn_units; overrides env.spawns[key]=[cell].
- Integracao: player_controller._unhandled_input retorna cedo se MapEditor.active; camera continua funcionando.
- v2 pendente: desenhar tabuleiro (add/remover casas/paredes) e atmosfera (luz/nevoa).
