# Estado Atual — 2026-08-21

## Status: DEMO JOGÁVEL E VALIDADA ✅

## O que funciona (testado headless + screenshots)
- Loop completo de partida: entrada → combate → boss → vitória/derrota
- 6000 frames em modo `--demo` (bot) sem NENHUM erro de script
- Bot percorreu: matou 2 goblins, trocou com arqueiro, revelou câmara do boss,
  morreu para o boss → game_over(false) emitido corretamente
- Screenshots reais capturados via Movie Maker: `screenshots/frame*.png` (1600×900)

## Como jogar
Abrir a pasta no Godot 4.x → PLAY.
- Clique: mover/atacar/alvo | Teclas 1–5: ações | ESC: cancela | WASD: câmera

## Modo validação automática
```
godot --headless --path . --quit-after 4000 ++ --demo   # bot joga sozinho
godot --path . --write-movie shot.png ++ --demo          # screenshots
```

## Próximo passo recomendado
Polimento de balanceamento da luta do boss (bot não usa poção/habilidade;
humano tem vantagem). Depois: áudio e save.

## Pendências conhecidas
- Nenhum bug aberto. Ver BUGS.md quando surgirem.
