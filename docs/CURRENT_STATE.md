# Estado Atual — 2026-08-22 — v0.4.0

## Status: DUNGEON KIT MULTI-ANDAR JOGÁVEL E VALIDADO ✅

## O que funciona (validado headless)
- 4 mapas modulares: `stone_keep` (3 andares, padrão), `tower`, `house`,
  `crypt` (passagem secreta + cofre) — todos bootam e jogam sem erros
- Movimento multi-andar com escadas ("Você muda de andar"), portas
  interativas (abrir/fechar/trancada/alavanca), passagem secreta disfarçada
- Combate completo no novo grid: LOS por andar, terreno alto (+1 atk),
  level up por abate, habilidades (projétil da maga, urso do druida)
- IA persegue por rota real (BFS multinível), não atravessa andares
- Bot de demo abre portas quando falta rota; sobe escadas; luta e morre

## Como jogar / validar
```
godot --path .                                    # editor/PLAY
godot --headless --path . --quit-after 3500 ++ --demo            # bot joga stone_keep
godot --headless --path . --quit-after 900 ++ --demo ++ --map=crypt
godot --headless --path . --quit-after 1500 ++ --clicktest       # clique sintético => OK
godot --headless --path . --quit-after 1500 ++ --skilltest       # projétil + urso => OK
```
Logs do bot: `[BOT]` (alvo/rota), `[R#]` (posições por rodada).

## Próximo passo recomendado
1. Câmera: ajustar limites/altura para mapas de 3 andares (ver andares
   de cima "cortados" é aceitável em visão de mesa)
2. Conteúdo: mais mapas usando o LEGEND (barato — só ASCII)
3. Trocar peças procedurais por assets GLB (Meshy) em TilePiece.PROPS
4. Depois: áudio e save

## Pendências conhecidas
- Nenhum bug aberto. BUG-006..010 resolvidos hoje (ver BUG_MEMORY).
