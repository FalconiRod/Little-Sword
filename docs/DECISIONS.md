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

## D12 - Escada reta = celulas reais com altura incremental (fim do link)
DATA: 2026-08-22 | STATUS: SUPERADA por D13
DECISAO: 'S' contiguos no ASCII viram escada; cada degrau e celula pisavel
com y absoluto FLOOR_H*(i+1)/(N+1); vizinho em andar adjacente vale quando
delta-y real <= 2.5 (STEP_MAX_DY). Nada de teleporte.
MOTIVO: escada vira terreno comum (parar no meio, custo normal, IA entende);
visual alinhado ao grid; uma unica regra de movimento para tudo.
ALTERNATIVAS: links/teleporte (v0.4.0, descartado: salto invisivel, bot
nao parava em degrau, dois sistemas de pathing).
IMPACTO: add_link removido; height_at suporta y custom; mapas reautorados.

## D14 - Porta sempre com passagem livre nos dois lados do eixo de abertura
DATA: 2026-08-22 | STATUS: ATIVA
DECISAO: ao carregar qualquer mapa, _validate_doors() exige que cada porta
tenha UM eixo (horizontal ou vertical) com as DUAS células adjacentes
caminháveis — o eixo por onde ela "abre". Eixo fechado dos dois lados
(porta em linha de parede) é ignorado; porta sem NENHUM eixo livre, ou
encostada em outra porta, gera push_warning na carga (erro de config do
mapa, nunca silencioso). Portas disfarçadas ('X') ficam fora da regra.
MOTIVO: porta que abre e não leva a lugar algum vira bug de gameplay
(jogador abre e não passa) — caso real do entulho atrás da porta (6,5,1)
do stone_keep, corrigido no mapa.
IMPACTO: mapas manuais novos e procedurais futuros são validados cedo;
warnings aparecem no console em dev.

## D13 - Escada = par de celulas ligadas; clicar nela cruza e desembarca a frente
DATA: 2026-08-22 | STATUS: ATIVA (v0.6.3; v0.6.1 e v0.6.2 SUPERADAS)
DECISAO: escada e UM par base<->topo (stair_links bidirecional); ambas as
celulas sao normais e entram no BFS como vizinhas de custo 1. Regra final
do usuario: CLICAR na casa da escada cruza automaticamente para o outro
andar, desembarcando no primeiro grid LIVRE a frente da escada de chegada
(stair_landing: vizinho ortogonal livre N/S/O/L). Chegar pelo salto
pareado (destino ja era outro andar) nao re-cruza. Passar pelo corredor
sem clicar na escada nao cruza. Em pe na escada, clicar de novo re-cruza
(try_cross_stairs, 1 MP). Saida bloqueada: fica na escada e avisa.
MOTIVO: o usuario quer transicao imediata ao clicar na escada, chegando
ja posicionado a frente (nao em cima da escada), nos dois sentidos.
HISTORICO: auto-cross ao terminar movimento (v0.6.1) teleportava sem
querer em corredores (BUG-017); v0.6.2 removeu todo auto-cross e o
usuario pediu o clique-direto de volta — versao final distingue "clicou
NA escada" (cruza) de "passou por ela" (nao cruza).
IMPACTO: dist_to_goal() intacta; mapas com "stairs": [[base],[topo]];
prop espiral fino (62% altura); _do_move desconta custo antes do await;
_do_move decide re-cruzamento comparando o penultimo passo do caminho.

## D15 - Regras taticas de combate: flanqueio, oportunidade, cobertura, Dispersar
DATA: 2026-08-22 | STATUS: ATIVA (v0.8.0)
DECISAO: pacote aprovado pelo usuario SEM combate base<->topo entre escadas.
(1) FLANQUEAR +2 ataque: corpo a corpo (chebyshev=1, mesmo andar) com
aliado do atacante na celula de lado OPOSTO do alvo (deslocamentos em
relacao ao alvo se anulam; diagonais opostas contam).
(2) ATAQUE DE OPORTUNIDADE: SAIR de celula adjacente a inimigo alertado
(mesmo andar) provoca 1 golpe gratis dele, uma vez por inimigo por
movimento. NAO provoca: quem usou Dispersar, troca de andar pela escada,
e passo que continua ao alcance do mesmo inimigo. Inimigos dormindo
(nao alertados) nunca reagem - preserva a aproximacao furtiva.
(3) COBERTURA +2 CA: do atacante para o alvo, se vizinho ORTOGONAL a
frente do alvo (na direcao do golpe; em diagonal avaliam-se os dois
cantos) for bloqueado (parede/pilar/entulho/porta fechada). Adjacencia
lateral direta nunca cobre.
(4) DISPERSAR: nova acao (botao [6] / tecla 6), consome a acao do turno;
sem provocar ataques ate o inicio do proximo turno (reset em _advance).
MOTIVO: dar profundidade tatica de posicionamento ao tabuleiro, estilo
D&D de mesa, sem mudar a economia existente (d20/CA/dano intactos).
HISTORICO: attack() so usava rotulo fornecido quando havia notacao de
dano; corrigido para rotulo do chamador sempre vencer ("Oportunidade").
IMPACTO: animate_move ganhou hook _provoke_leaving (roda para herois E
IA); IA ainda nao usa Dispersar (melhoria futura); combates ficaram mais
mortais ao recuar sem dispersar; COMBATTEST valida as 4 regras (4/4).