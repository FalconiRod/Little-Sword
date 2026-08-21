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
- Coordenadas: célula Vector2i(x,z); mundo = célula * BoardGrid.TILE (2.0).
- Frente das miniaturas = +Z (atan2 em face_towards).

## Roadmap curto
Balancear boss → áudio procedural → save → segundo herói (mago) → campanha.
