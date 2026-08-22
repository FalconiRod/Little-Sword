# Estado Atual — 2026-08-22 — v0.5.0

## Status: ESCADAS RETAS POR CÉLULAS REAIS — JOGÁVEL E VALIDADO ✅

## O que funciona (validado headless)
- 4 mapas modulares: `stone_keep` (3 andares, padrão), `tower`, `house`,
  `crypt` (passagem secreta + cofre) — todos bootam e jogam sem erros
- **Escadas retas novas**: cada degrau é célula real do grid com altura
  incremental; unidade pode PARAR NO MEIO da escada; subir = andar
  célula a célula (mesmo custo); sem teleporte
- Iluminação atmosférica (lua + tochas tremulantes) em todos os mapas
- Câmera presa ao andar ativo; retratos clicáveis levam ao herói;
  troca de andar com fade preto
- Combate completo: LOS por andar, terreno alto (+1 atk), level up,
  habilidades; IA persegue por rota real (BFS multinível)
- Bot de demo sobe/desce escadas nos 3 mapas multi-andar (validado:
  "Você muda de andar" + engaja boss no andar de cima)

## Como jogar / validar
```
godot --path .                                    # editor/PLAY
godot --headless --path . --quit-after 3500 ++ --demo            # bot joga stone_keep
godot --headless --path . --quit-after 5000 ++ --demo ++ --map=tower|crypt
godot --headless --path . --quit-after 1500 ++ --clicktest       # clique sintético => OK
godot --headless --path . --quit-after 1500 ++ --skilltest       # projétil + urso => OK
```
Logs do bot: `[BOT]` (alvo/rota), `[R#]` (posições por rodada).

## Próximo passo recomendado
1. Conteúdo: mais mapas usando o LEGEND (barato — só ASCII; 'S'
   contíguos viram escada automaticamente)
2. Combate entre alturas próximas (degrau ↔ landing) hoje é bloqueado
   por exigir mesmo andar — decidir se vira regra (ataque em Δy≤2.5)
3. Trocar peças procedurais por assets GLB (Meshy) em TilePiece.PROPS
4. Depois: áudio e save

## Pendências conhecidas
- Nenhum bug aberto. BUG-011..013 resolvidos hoje (ver BUG_MEMORY).
- Autoria de ASCII: conferir contagem de colunas dos 'S' (off-by-one
  já causou escada quebrada — ver DISCOVERY no BUG_MEMORY).
