# Estado Atual - 2026-08-23 - v0.9.0

## Status: PISO-FOLHA BATTLE-GRID ATIVO (mapa grande 50x50 + grade impressa)

## O que funciona (validado headless + windowed RX580)
- 4 mapas modulares carregam sem warnings (portas/escadas validadas)
- Transicao de escada em 1 clique, estavel (stairtest 8/8)
- COMBATE: d20 vs CA, critico, dano por dados + regras taticas D15:
  * flanquear +2 ataque (lado oposto do alvo)
  * ataque de oportunidade ao sair da adjacencia (1x/inimigo/movimento)
  * cobertura +2 CA (obstaculo na direcao do golpe)
  * acao Dispersar [6] imune a oportunidade ate proximo turno
- NOVO PISO-FOLHA (D16): mapas com chave "sheet" trocam os pisos por
  celula por UMA malha mesclada com a folha do usuario repetida
  (20x20 celulas/folha = 400 casas, celula de 2,4 cm na impressao),
  alinhada a origem; grade vetorial via shader next_pass por cima;
  paredes/arvores continuam miniaturas EM CIMA da folha ('~' fica sem)
- NOVO MAPA bosque_50: procedural 50x50 deterministico (seed 20260823,
  flood-fill garante conectividade dos spawns), IA navega rotas de 20+
  passos; camera pan/zoom derivados do tamanho real do mapa
- COMBATTEST 4/4; STAIRTEST 8/8; CLICKTEST OK; SKILLTEST OK

## Como jogar / validar
godot --path . --map=bosque_50                           # PLAY mapa novo
godot --headless --path . --quit-after 900 -- --demo --map=bosque_50
godot --headless --path . --quit-after 1200 -- --combattest --map=tower
godot --headless --path . --quit-after 1200 -- --stairtest --map=tower
godot --headless --path . --quit-after 4000 -- --demo [--map=X]
godot --headless --path . --quit-after 1500 -- --clicktest / --skilltest

## Proximo passo recomendado
1. Ver in-game as costuras da folha no bosque_50 (corrigir bordas se
   visiveis) e afinar opacity da grade (uniform grid_opacity no mapa def)
2. Props GLB do usuario no lugar das arvores 'P'/rochas 'o' (com AABB
   ~1,8 unid) e miniaturas GLB para unidades
3. IA usando Dispersar ao recuar / flanqueando em dupla
4. Depois: audio e save

## Pendencias conhecidas
- Combate base<->topo entre celulas pareadas da escada: EXCLUIDO por
  decisao do usuario na D15 (revisitavel no futuro)
- Costura entre repeticoes da folha ainda nao inspecionada visualmente
  (textura de IA pode nao ser seamless perfeita nas bordas)
- cells_per_sheet=20 confirmado pelo usuario; grade impressa na arte deve
  coincidir com o shader - conferir em jogo
