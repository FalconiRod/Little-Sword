# SESSION MEMORY — 2026-08-21

## Feito
- Projeto criado do zero em D:\PROJETOS\Little sword
- 16 scripts GDScript + project.godot + main.tscn
- Validação headless: 0 erros após correções de inferência de tipo (Variant ==)
- Bot demo jogou partida completa: goblins mortos → arqueiro → boss room revelada
  → derrota do bot para o boss (game_over false) — todos os caminhos exercitados
- 111 screenshots reais via Movie Maker (screenshots/frame*.png, 1600×900)
- Verificação programática de pixels confirmou renderização correta (paleta dark)

## Descobertas
- Godot precisa de `--import` inicial para gerar cache de classes globais
  (class_name) em projeto novo; sem isso, parse errors falsos.
- `:=` não infere tipo de comparações com Variant (ex.: TurnManager.active == u)
  → tipar explícito `: bool`.
- Movie Maker funciona no binário não-console; ~4% da velocidade real em CPU.

## Estado final da sessão
Demo v0.1.0 jogável e validada. Documentação completa. Pronto para iterar.

## Sessão 2 — 2026-08-21 (percepção + balance)
- LOS por amostragem de segmento no grid (passos de TILE*0.25)
- Aggro: alerted individual + propagação em área no primeiro golpe recebido
- Bug morto: apply_to_unit órfão (anel de defesa inerte desde v0.1.0)
- Demo bot validou: guarda -> avistou -> combate; derrota do bot no boss é
  esperada (bot não usa defender/poções/habilidade)

## Sessão 3 — 2026-08-21 (câmera mouse + publicação)
- Rotação primária por arrasto do botão direito; clique sem arrasto cancela mira
- Backup v0.1.4 em D:\PROJETOS\BACKUPS (16 MB) e repo público no GitHub criado

## Sessao 2026-08-22 (v0.4.0 - Dungeon Kit)
Feito: kit modular src/dungeon (tile_piece/door/stairs/environment_manager,
4 mapas ASCII); BoardGrid multinivel Vector3i + elevacao + links; BFS
multinivel com ignore_units; portas/alavancas interativas; terreno alto
+1 atk; IA e bot usam rota real entre andares; click prioriza andar do
heroi; HUD a prova de heroi morto.
Descobertas: class_name novo exige --import; chebyshev sem Z engana
perseguicao multi-andar (BUG-007); chars de mapa precisam entrada no
LEGEND ou viram parede (BUG-008); Start-Process com ArgumentList precisa
de aspas embutidas p/ caminhos com espaco.
Validacao: demo 4 mapas OK, clicktest OK, skilltest OK, boot limpo.
Pendente: camera p/ 3 andares; assets GLB; audio/save.

## Sessao 3 - 2026-08-22 (luzes, camera por andar, escadas retas v0.5.0)
- Feito: atmosfera luminosa (lua+tochas); camera presa ao andar ativo com
  fade na troca; retratos clicaveis; ESCADAS RETAS reescritas: celulas 'S'
  contiguas = degraus reais com altura incremental; neighbors cruza andar
  por delta-y <= 2.5; stairs.gd/links eliminados; mapas reautorados
- Descobertas: ver BUG-011..013 + DISCOVERY off-by-one ASCII
- Validacao: demo sobe/desce em stone_keep/tower/crypt; clicktest OK;
  skilltest OK; boot sem erros
- Pendencia: combate em altura proxima (degrau vs landing) bloqueado por
  regra mesmo-andar - decidir regra futura

## Sessao 3b - 2026-08-22 (v0.6.0 StairsLink)
- Feito: modelo de escada substituido por PAR de celulas ligadas
  (stair_links); transicao unica via animate_move; prop espiral unico +
  marcador ambar no topo; dist_to_goal para IA/bot cross-floor; mapas com
  "stairs": [[base],[topo]]; BUG-014 (freed target) corrigido; backup e
  commits antes/depois conforme pedido do usuario
- Descobertas: auto-cross gera vai-e-vem (BUG-015) - transicao so no passo
  do caminho; dado alto no skilltest exp�s freed-target latente
- Validacao: 4 mapas demo OK (7 travessias), clicktest OK, skilltest 6/6

## Sessao 3c - 2026-08-22 (v0.6.1 cross ao terminar movimento + stairtest)
- Feito: spec do usuario aplicada — terminar o movimento SOBRE celula
  ligada cruza (_cross_stairs_now, custa 1 MP; sem MP, para e cruza no
  turno seguinte andando ate o par); guarda anti-duplo via penultimo
  passo; _do_move desconta custo ANTES do await (BUG-016); teste
  --stairtest --map=tower com 4 cenarios incluindo "parar sem movimento"
  (pedido explicito do usuario)
- Descobertas: contrato animate_move = move_unit(path[-1]) antes (teste
  violou e mascarou bug); TurnManager corre por cima de testes;
  "pedra na porta do 2 andar" era geometria v0.5.0, inexistente hoje
- Validacao: STAIRTEST 4/4 OK; demos stone_keep/tower/crypt/house sem
  erro/ML negativo/quique; CLICKTEST OK; SKILLTEST OK (mapa padrao)
- Pendente: combate base<->topo bloqueado por regra mesmo-andar (decisao
  futura); prop Meshy no lugar da espiral procedural

## Sessao 3d - 2026-08-22 (v0.6.2 travessia explicita, BUG-017)
- Feito: usuario rejeitou o cross ao terminar movimento (clicar na escada
  como destino teleportava sem querer). Removido gatilho; travessia agora
  so via salto pareado no caminho ou try_cross_stairs() (em pe na celula,
  clicar de novo, custa 1 MP); prop espiral emagrecido (62% altura) para
  nao ler como "pedra" no corredor; stairtest reescrito com 5 cenarios
- Descobertas: celulas de escada costumam ser corredor (stone_keep linha
  7) - auto-cross nelas quebra a navegacao normal do piso
- Validacao: STAIRTEST 5/5; demos tower/stone_keep com travessias apenas
  cross-floor; CLICKTEST OK; SKILLTEST OK

## Sessao 3e - 2026-08-22 (v0.6.3 clique-na-escada cruza + desembarque a frente)
- Feito: spec final do usuario — clicar na casa da escada cruza
  automaticamente e desembarca no primeiro grid LIVRE a frente da escada
  de chegada (BoardGrid.stair_landing, ordem N/S/O/L); salto pareado no
  caminho nao re-cruza (compara penultimo passo); saida bloqueada avisa;
  stairtest cenario 4 valida o grid exato de desembarque
- Descobertas: stair_landing deve ser computado ANTES da travessia nos
  testes (depois, a propria unidade ocupa a celula N e muda o resultado)
- Validacao: STAIRTEST 5/5; demos com sobe/desce nos dois modos; msg
  "Saida da escada bloqueada" exercitada no demo tower; CLICKTEST/SKILLTEST OK

## Sessao 3f - 2026-08-22 (v0.6.4 desembarque tolerante, BUG-018)
- Feito: usuario clicou na escada e levou "ocupado acima" sem subir —
  causa: stair_landing so olhava 4 ortogonais (coluna P atras da escada
  de cima + unidades nas laterais). Diagonais como reserva (8 saidas);
  try_cross_stairs retorna codigo 0/1/2 com mensagens exatas por motivo;
  stairtest cenario 6 cobre bloqueio total + liberacao
- Validacao: STAIRTEST 6/6; demo stone_keep sobe/desce OK; CLICKTEST/
  SKILLTEST OK

## Sessao 3g - 2026-08-22 (v0.7.0 causa raiz da transicao + regra de porta)
- Feito: CAUSA RAIZ do bug da escada achada — unit_changed_floor nunca
  sincronizava active_floor_index/camera (heroi invisivel, andar antigo
  visivel, clique extra "completando" a ida). Handler _on_unit_changed_
  floor faz visibilidade+fade+snap na hora. Travessia em 1 clique
  garantida (fallback em pe no par). Regra D14 _validate_doors pegou o
  entulho atras da porta (6,5,1) do stone_keep — mapa corrigido; 4 mapas
  sem warnings. STAIRTEST 7/7
- Descoberta: set_active_floor so era chamado em retrato/turno — eventos
  de movimento precisam sincronizar estado visual eles mesmos

## Sessao 3h - 2026-08-22 (v0.7.1 tween orfao do arco - BUG-021)
- Sintoma do usuario: clicar na escada fazia as pecas irem para BAIXO do
  tabuleiro em vez de subir
- Investigacao: instrumentacao progressiva (prints pos-cenario, janela
  temporal, _process com detector de mudanca de Y + frame number) provou:
  y=0.0 correto apos change_floor, e y=7.0 EXATO no frame seguinte -
  assinatura de TWEEN, nao de codigo direto
- Causa raiz: th (tween do arco do salto, position:y) nao era aguardado
  em animate_move; no fluxo real ele escrevia o y do andar antigo POR
  CIMA do change_floor no frame seguinte
- Fix: await th.finished; stairtest 7 -> 8 cenarios (asserts de Y +
  fluxo real com janela 0.5s para heroi E camera)
- Validado: stairtest 8/8, demos x4 sem warnings, clicktest OK,
  skilltest OK
- Licoes: (1) tween paralelo nao aguardado = escrita fantasma posterior;
  (2) recalcular landing DEPOIS do cross e inconsistente (heroi ocupa o
  proprio desembarque) - capturar antes
## Sessao 3i - 2026-08-22 (v0.8.0 regras taticas de combate - D15)
- Usuario escolheu pacote completo MENOS combate base<->topo de escada
- Implementado: flank_bonus/cover_ac em combat_system.attack();
  _provoke_leaving dentro de animate_move (hook unico p/ heroi e IA);
  do_disengage + botao [6]/tecla 6; reset disengaging em _advance
- Pegadinha corrigida: attack() ignorava skill_label sem notacao de dano -
  rotulo "Oportunidade" virava "Ataque" e o teste nao contava
- COMBATTEST novo (4 cenarios); bateria completa verde
- Pendente: IA ainda nao dispersa/flanqueia por conta propria## Sessao 3j - 2026-08-23 (v0.9.0 piso-folha battle-grid - D16)
- Usuario especificou a folha: 400 celulas (20x20), celula 2,4x2,4 cm
- Implementado: modo sheet no environment_manager (malha unica + UV
  mundial + shader de grade next_pass), mapa procedural bosque_50 com
  flood-fill de conectividade, camera dinamica via map_bounds()
- Licoes Godot 4.7 desta sessao:
  (1) const MAPS congela dicionarios aninhados -> duplicate(true) antes
      de mutar (erro "Dictionary is in read-only state")
  (2) GeometryInstance3D.cast_geo/GEOMETRY_OFF nao existem mais ->
      cast_shadow = SHADOW_CASTING_SETTING_OFF
  (3) BaseMaterial3D sem TEXTURE_REPEAT_*: shader spatial repete
      textura por padrao quando UV > 1
  (4) surface winding duvidoso? cull_mode DISABLE + normal explicita
      resolve sem depender de convencao
  (5) JPG novo precisa de --import headless antes de usar em runtime
- Textura importada e validada; windowed RX580 exit 0
- Pendente: inspecionar costuras/opacidade da grade in-game; props GLB
- Descoberta 3j-b: argumentos do jogo (--map=, --demo...) exigem o separador '--' antes; sem ele o Godot consome/ignora e main.gd cai no mapa padrao (stone_keep) SEM erro - usuario viu 'jogo sem mudanca'. Corrigido no JOGAR_bosque.bat

- Usuario achou 50x50 grande demais -> v0.9.1: bosque_30 (30x30); gerador agora usa spawns PROPORCIONAIS ao w/h; bat atualizado; validado (combate na rodada 1)

- v0.9.2 (D17): convencao unica de grid - centro = col*TILE+TILE/2; grid_to_world/world_to_cell canonicos em BoardGrid; roundi/floori avulsos proibidos fora deles; causa do desalinhamento era a folha imprimir linhas nas bordas enquanto o codigo centrava celulas em pares

- Folha v2: usuario trocou bosque.jpg por versao com grade 50x50 impressa (5908px, ~118px/celula); cells_per_sheet 20->50; mapa 30x30 cabe em UMA folha (zero costuras)

- v0.9.4: sistema tile-GLB pronto - _build_tile_multimeshes instancia UM glb de casa via MultiMesh (1 draw call), escala AABB->TILE=2.0, topo em y=0, centro na celula; ativado por 'tile_glb': pasta no map def; sem glb cai para folha. Usuario vai fornecer o modelo

- v0.9.5: tile GLB do bosque FUNCIONANDO - usuario forneceu 'piso modelo bosque.glb' (meshopt+quantizado); convertido p/ float32 (deq.cjs) como tile_bosque.glb; MultiMesh monta tabuleiro casa a casa; BUG-024 registrado (tripo pendentes)

- v0.9.6: cavaleiro agora usa GLB real do Ranger (ranger.glb renomeado p/ ASCII; reimport necessario apos renomear texturas); _glb_piece normaliza: pe em y=0, centrado, altura 1.55 (PIECE_HEIGHT). Fallback procedural mantido.

- v0.9.7: TODAS as pecas com GLB real (ranger/maga/druida/urso/2 goblins/hobgoblin boss), alturas por peca (boss 1.95, goblins 1.10, urso 1.30); circulos brilhantes (_base) removidos; retopologia geral (SOL-012) resolveu travamento

- v0.9.8: fix freeze do urso - texturas 8K/4K -> 1024px em todos os GLBs (<1MB cada); guard AABB degenerado; skilltest janela OK

- doc: criado docs/PROJETO_COMPLETO.md - historia estrutural integral v0.1.0->v0.9.8 (62 commits, sistemas, pipeline de assets, decisoes, bugs, validacao, pendencias)

- FASE 1 do ROADMAP: checklist aplicada nos 5 tripo existentes (copy->deq->weld->simplify->resize + lods/shadow/tangentes off no .import, SOL-014); todos importam OK ~58k tris; docs/ROADMAP.md criado

- FASE 2: fix camera girando (SOL-015) - watchdog de drag orfao + clamps de delta/motion/velocidade angular; sensibilidade ja clampada

- FASE 3 parcial: GLBs virados 180graus (frente IA=-Z, jogo=+Z); pulo entre casas 0.17s->0.26s, arco SINE 0.22 mais organico; alinhamento e proporcao aprovados pelo usuario

- FASE 3: facing corrigido de novo (removido giro 180 - modelos sao +Z nativo); BUG-025 congelamento resolvido (guardas alive + tween unico em animate_move)

- Editor de mapa v1 criado (F1): props/GLB/spawns com save JSON em user://; skilltest OK

- Editor v2 completo conforme spec do usuario (biblioteca categorizada c/ thumbnails SubViewport, transformacao rot90+escala uniforme/avancada, troca piso, escadas, save c/ validacao D14, pausa de turnos); skilltest OK

