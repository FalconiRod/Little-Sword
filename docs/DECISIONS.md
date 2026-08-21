# Decisões Técnicas

## D1 — Construção 100% em código (só main.tscn)
DATA: 2026-08-21 | STATUS: ATIVA
MOTIVO: .tscn hand-written é propenso a quebrar; código dá diff/validação headless.
ALTERNATIVAS: cenas .tscn por unidade (descartado: frágil sem editor).

## D2 — Autoloads para sistemas, EventBus para desacoplar
DATA: 2026-08-21 | STATUS: ATIVA
HUD não conhece combate; combate emite sinais. IA e jogador falam com
TurnManager pela mesma interface.

## D3 — Raycast matemático no plano y=0 (sem física)
DATA: 2026-08-21 | STATUS: ATIVA
Picking de células por interseção raio-plano + arredondamento ao grid.
Zero CollisionShape; mais simples e determinístico.

## D4 — Renderer gl_compatibility
DATA: 2026-08-21 | STATUS: ATIVA
Abre em qualquer máquina (OpenGL), suficiente para o visual dark fantasy
(emissivos + luzes + fog). Vulkan forward+ opcional no futuro.

## D5 — Ordem de turno fixa (sem iniciativa rolada)
DATA: 2026-08-21 | STATUS: ATIVA
Especificação pede ordem fixa Cavaleiro→Goblins→Arqueiro→Boss. Simples e legível.
