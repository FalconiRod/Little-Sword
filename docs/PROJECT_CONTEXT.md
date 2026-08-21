# Little Sword — Tactical Board RPG

## Identidade
Demo jogável (vertical slice) de RPG tático por turnos em tabuleiro digital,
dark fantasy, inspirado em D&D / XCOM / jogos de mesa digitais.

## Pilar central
"Você está jogando uma partida de D&D sobre uma mesa digital."
Peças = miniaturas com base circular. Nada de movimento livre.

## Stack
- Godot 4.7 (GDScript), renderer gl_compatibility
- Zero assets externos: tudo procedural (malhas, materiais, UI)

## Regras D&D implementadas
- D20 + modificador vs Classe de Armadura; nat 20 = crítico (dobra dados); nat 1 = falha crítica
- Movimento por pontos: D6 por rodada do herói (1–2 → metade, 3–6 → cheio)
- Dano por notação: espada 1d8+3, goblins 1d6(+1), boss 1d12+4
- Defender: +4 CA até o próximo turno
- Habilidade: Golpe Poderoso 2d8+3, custo 3 mana (regen +2/rodada)
