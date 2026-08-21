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
