# Estado Atual — 2026-08-22 — v0.6.1

## Status: STAIRSLINK + CROSS AO TERMINAR MOVIMENTO — JOGÁVEL E VALIDADO ✅

## O que funciona (validado headless)
- 4 mapas modulares: `stone_keep` (3 andares, padrão), `tower`, `house`,
  `crypt` (passagem secreta + cofre) — todos bootam e jogam sem erros
- **Escada = par de células ligadas** (`stairs`: [[base],[topo]]): ambas
  são células normais do grid; subir/descer custa entrar na célula
  pareada (1 passo, sem ação especial)
- **Transição em dois gatilhos** (v0.6.1): (a) caminho executa o salto
  pareado; (b) movimento TERMINA sobre célula ligada sem ter chegado
  pelo salto — custa 1 MP; sem MP, para na escada e cruza no turno
  seguinte andando até a célula pareada; sem cross de início de turno
- Visual: prop único de escada espiral na célula base + marcador âmbar
  no topo (pronto para trocar por modelo do Meshy)
- IA e bot perseguem alvos em outros andares via `dist_to_goal`
  (BFS + propagação pelos pares); bot cruza escadas nos 3 mapas
- Iluminação atmosférica; câmera presa ao andar com fade; retratos
  clicáveis; combate completo (LOS, terreno alto, level up, habilidades)

## Como jogar / validar
```
godot --path .                                    # editor/PLAY
godot --headless --path . --quit-after 3500 ++ --demo            # bot joga stone_keep
godot --headless --path . --quit-after 6000 ++ --demo ++ --map=tower|crypt
godot --headless --path . --quit-after 1500 ++ --clicktest       # clique sintético => OK
godot --headless --path . --quit-after 1500 ++ --skilltest       # projétil + urso => OK
godot --headless --path . --quit-after 3000 ++ --stairtest ++ --map=tower   # escada 4/4 => OK
```

## Próximo passo recomendado
1. Substituir o prop procedural por modelo GLB do Meshy: trocar apenas o
   builder `stairs_prop` em TilePiece (degraus esculpidos no modelo)
2. Conteúdo: novos mapas só com ASCII + pares "stairs"
3. Regra futura: combate entre células pareadas (base↔topo) hoje exige
   mesmo andar — decidir se ataca através da escada
4. Depois: áudio e save

## Pendências conhecidas
- Nenhuma bloqueante. BUG-011..016 resolvidos (ver BUG_MEMORY).
