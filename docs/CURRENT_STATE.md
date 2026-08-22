# Estado Atual - 2026-08-22 - v0.8.0

## Status: REGRAS TATICAS DE COMBATE ATIVAS (flanqueio/oportunidade/cobertura/dispersar)

## O que funciona (validado headless)
- 4 mapas modulares carregam sem warnings (portas/escadas validadas)
- Transicao de escada em 1 clique, estavel (stairtest 8/8)
- COMBATE: d20 vs CA, critico, dano por dados + regras taticas D15:
  * flanquear +2 ataque (lado oposto do alvo)
  * ataque de oportunidade ao sair da adjacencia (1x/inimigo/movimento)
  * cobertura +2 CA (obstaculo na direcao do golpe)
  * acao Dispersar [6] imune a oportunidade ate proximo turno
- IA cross-floor; combate completo; retratos com fade
- COMBATTEST 4/4; CLICKTEST OK; SKILLTEST OK

## Como jogar / validar
godot --path .                                            # PLAY
godot --headless --path . --quit-after 6000 -- --combattest --map=tower
godot --headless --path . --quit-after 5000 -- --stairtest --map=tower
godot --headless --path . --quit-after 4000 -- --demo [--map=X]
godot --headless --path . --quit-after 1500 -- --clicktest / --skilltest

## Proximo passo recomendado
1. IA usando Dispersar ao recuar (e flanqueando em dupla) - melhoria tatica
2. Prop GLB do Meshy no lugar da espiral procedural
3. Novos mapas (portas/escadas ja validadas na carga)
4. Depois: audio e save

## Pendencias conhecidas
- Combate base<->topo entre celulas pareadas da escada: EXCLUIDO por
  decisao do usuario na D15 (revisitavel no futuro)