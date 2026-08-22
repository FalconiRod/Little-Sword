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

## D8 — Colisão da câmera sem física (2026-08-21)
DECISÃO: raycast substituído por amostragem do segmento pivô->câmera no
BoardGrid (bloqueia se amostra cai em célula '#' abaixo de y=2,1).
MOTIVO: projeto é physics-free; evita criar StaticBody para ~90 paredes.
ALTERNATIVAS DESCARTADAS: StaticBody+intersect_ray (peso extra sem ganho).
IMPACTO: colisão barata, determinística e já testada via LOS do grid.

## D9 — SpringArm3D exige física nas paredes (2026-08-21)
DECISÃO: gerar StaticBody3D+BoxShape por parede na layer 2; mola usa
collision_mask=2. D8 (amostragem grid) fica SUPERADO.
MOTIVO: arquitetura TacticalCamera adotada depende da mola para colisão.
IMPACTO: ~90 corpos estáticos criados uma vez no build; gameplay segue sem física.

## D10 — Colisao da mola desligada (2026-08-21) — SUPERADORES D9/D8
DECISAO: SpringArm3D.collision_mask=0 + teto dinamico MAX_HORIZON.
MOTIVO: colisao com paredes teleportava/travava a camera (relato do usuario);
estabilidade > oclusao realista num jogo top-down tatico.
IMPACTO: camera pode sobrepor paredes visualmente em angulos baixos raros;
corpos layer 2 permanecem no mapa para uso futuro.

## D11 — Multi-heroi no mesmo controlador (2026-08-21)
DECISAO: PlayerController generalizado ('knight' = heroi ativo do turno);
TurnManager roteia todo team hero para o controle humano; IA escolhe alvo
pela menor distancia Chebyshev.
MOTIVO: party cresce sem duplicar controladores; HUD/retrato mostram o heroi
da vez; habilidades viram dados declarativos em UnitDefs.SKILLS.
IMPACTO: novos herois = entrada em DEFS + SKILLS + builder visual + spawn.

## D12 - Grid multinivel Vector3i + Dungeon Kit modular (2026-08-22)
DECISAO: BoardGrid migrado para celulas Vector3i(x,y,andar) com elevacao
por tile e links de escada; cenario vira kit de pecas (src/dungeon/)
gerado de mapas ASCII por andar (EnvironmentManager).
MOTIVO: pedido do usuario - multi-andares, escadas, portas interativas,
plataformas, visao de mesa tatica; pecas modulares permitem trocar por
assets GLB (Meshy) sem tocar na logica.
IMPACTO: chebyshev ignora z (usar rota BFS p/ perseguicao); LOS apenas
no mesmo andar; ataques melee exigem mesmo andar; bonus terreno alto.

## D13 - Click prioriza o andar do heroi ativo (2026-08-22)
DECISAO: _mouse_cell testa primeiro o plano do andar do heroi; so olha
os outros andares se nada for atingido.
MOTIVO: andares empilhados se sobrepoe na tela; intersecao mais proxima
escolhia tile de cima e travava o jogo no chao.
IMPACTO: clicar em outro andar exige apontar fora da sobreposicao.
