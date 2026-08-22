# Estado Atual - 2026-08-22 - v0.7.1

## Status: ESCADA ESTAVEL (8/8) - tween orfao do arco eliminado (BUG-021)

## O que funciona (validado headless)
- 4 mapas modulares (stone_keep 3 andares, tower, house, crypt)
  carregam sem nenhum warning de configuracao
- Transicao de escada em UM clique: fade + troca de andar + camera
  sincronizados no proprio evento; heroi nunca invisivel nem afundando
- Clicar na casa da escada cruza automaticamente e desembarca no
  primeiro grid livre a frente (8 direcoes); fallback em pe no par;
  codigo 2 so se ate o par estiver ocupado
- Chegar pelo salto nao re-cruza; corredor nao cruza; re-click re-cruza
- Regra D14: portas validadas na carga (eixo de abertura livre,
  sem porta encostada); pareamento de escada tambem validado
- IA/bot cross-floor; combate completo; retratos com fade
- STAIRTEST 8/8 incluindo fluxo real (andar + cruzar mesmo frame)

## Como jogar / validar
godot --path .                                          # PLAY
godot --headless --path . --quit-after 5000 -- --stairtest --map=tower
godot --headless --path . --quit-after 3500 -- --demo [--map=X]
godot --headless --path . --quit-after 1500 -- --clicktest / --skilltest

## Proximo passo recomendado
1. Prop GLB do Meshy no lugar da espiral procedural
2. Novos mapas (portas/escadas ja validadas na carga)
3. Combate entre celulas pareadas (base<->topo) - decidir regra
4. Depois: audio e save

## Pendencias conhecidas
- Nenhuma bloqueante. BUG-001..021 resolvidos (ver BUG_MEMORY).