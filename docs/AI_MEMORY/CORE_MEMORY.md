# CORE MEMORY — Little Sword

IDENTIDADE: RPG tático por turnos em tabuleiro digital, dark fantasy.
NÃO É ação/Zelda. Peças = miniaturas com base; combate por turnos estilo D&D.

TECNOLOGIA: Godot 4.7, GDScript, renderer gl_compatibility, zero assets externos.

REGRAS FUNDAMENTAIS:
1. Movimento SEMPRE por grid/células com pontos de movimento (nunca livre).
2. Todo ataque = D20 + modificador vs CA (nat20 crítico, nat1 falha).
3. Sistemas em autoloads; comunicação via EventBus (sinais).
4. Validar sempre: `--headless --quit-after N ++ --demo` deve ter 0 erros.
5. Fonte de verdade: código > docs > conversa.

COMO RODAR: abrir pasta no Godot 4.x e apertar PLAY (main.tscn).

MAPA: BoardBuilder.MAP (ASCII 13×15). Salas em ROOMS com névoa configurável.
