# Handoff — para o próximo agente

LER PRIMEIRO: docs/CURRENT_STATE.md, docs/ARCHITECTURE.md, docs/AI_MEMORY/CORE_MEMORY.md

## Resumo operacional
Demo Godot 4.7 jogável e validada. Nada quebrado aberto. Não há arte externa —
tudo procedural em GDScript; não "consertar" falta de assets, é intencional.

## Como validar qualquer mudança
```
& "godot_console.exe" --headless --path . --quit-after 300   # sem erros?
& "godot_console.exe" --headless --path . --quit-after 4000 ++ --demo   # bot joga
```

## Pontos sensíveis
- Autoloads conectam sinais do EventBus: se conectar em setup(), desconectar
  antes de reconectar (TurnManager já faz) — senão duplica handlers após restart.
- `Engine.time_scale=3` só no modo demo.
- Coordenadas: célula Vector3i(x,y,z); mundo = célula * BoardGrid.TILE (2.4). Grid automático 2,4×2,4 sobre estruturas via SOBE (raycast + elev).
- Tilesets unificados em `src/assets/tilesets/` — battlemat e por-célula compartilham lista (`_glb_tiles`/`_mat_candidates`).
- Frente das miniaturas = +Z (atan2 em face_towards).

## Roadmap curto
Balancear boss → áudio procedural → save → segundo herói (mago) → campanha.

## Repositório
https://github.com/FalconiRod/Little-Sword  (branch main, público)
Backup local mais recente: D:\PROJETOS\BACKUPS\Little-Sword_v0.1.4_2026-08-21.zip
