
## PIPELINE APROVADO (2026-08-23) — disparo: usuario diz "vamos para fase A"
Prioridade atual: FINALIZAR BOSQUE para DEMO/VIDEO antes de comecar as fases.

- FASE A — PieceDef (.tres por tipo de peca) + registro-fachada compativel
  com TilePiece.PROPS/CAT_* do editor F1 (ids estaveis). Pre-requisito de tudo.
- FASE B — StairsLink(Resource, nao existe hoje) + TilePlacement +
  MapLayoutDefinition + carregador novo no EnvironmentManager (mesma logica
  de instanciamento, nova fonte de dados).
- FASE C — Migrar stone_keep/tower/house/crypt para .tres gerados
  programaticamente do ASCII atual (visual identico, validado por teste).
- FASE D — Overlay bosque_30_overrides.tres por cima do procedural
  (manual vence); aplicar apos geracao, perto de map_bounds(); seed travada.
- FASE E — CharacterDefinition/SkillDefinition/ItemDefinition (.tres);
  eliminar duplicacao de skills em main.gd:104-106 (fonte unica).
- FASE F — hud.tscn (UI hoje 100% codigo: 91 .new()/add_child). Por ultimo.

Regras: pausa+testes (--demo/--skilltest/--combattest/--editortest) ao fim
de cada fase; editor F1 nunca quebrar; retrocompat total do bosque.
Auditoria completa desta decisao: conversa 2026-08-23 (docs .tres enviados
pelo usuario). NAO confundir com sandbox/decor-export resetados (130b52e).
