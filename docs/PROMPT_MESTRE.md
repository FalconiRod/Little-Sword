# PROMPT MESTRE — Little Sword: Tactical Board RPG

> Documento completo de handoff: visão, mecânicas, estado, histórico e roadmap.
> Serve para qualquer dev ou IA continuar o projeto do zero, sem contexto anterior.

---

## 1. IDENTIDADE E VISÃO DO JOGO

**Little Sword — Tactical Board RPG** é uma demo jogável (vertical slice) de um
RPG de mesa digital em turnos, estilo tabuleiro físico de Dungeons & Dragons:
miniaturas sobre uma masmorra escura iluminada por tochas, vistas por uma
câmera orbital que circunda a mesa como um jogador real.

**Intenção central:** fazer o jogador SENTIR que está olhando um tabuleiro real
de D&D — peças pintadas sobre bases circulares, casas visíveis, dados rolando,
e a liberdade de se inclinar sobre a mesa e inspecionar cada miniatura.

**Pilares de design:**
1. **Leitura tática acima de tudo** — o campo deve ser legível de qualquer ângulo.
2. **Peso e materialidade** — movimento com inércia, impactos com shake,
   miniaturas "físicas" (nunca tokens planos).
3. **Dados como espetáculo** — cada rolagem é mostrada; crítico e falha crítica
   têm momento próprio.
4. **Zero assets externos** — 100% procedural (GDScript + primitivas 3D).
5. **Estilo BG3/Solasta na câmera**, XCOM na clareza das ações.

## 2. ESTILO VISUAL

- Dark fantasy: tons quase pretos (`#1d1d25` paredes, `#2b2b33` piso xadrez),
  luz quente de tochas (laranja tremulante), névoa de exploração por sala.
- Miniaturas: corpos low-poly com capuz/ombros/arma, base circular tipo resina,
  anel de seleção ciano brilhante no herói.
- Destaques de casa: azul = mover, vermelho = alvo, amarelo = interação.
- UI escura com dourado discreto; log de combate estilo "narrador de mesa".
- Renderer `gl_compatibility` (leve, roda em qualquer PC).

## 3. STACK E ARQUITETURA

- **Godot 4.7.2 stable** (portátil em `D:\PROJETOS\_tools\godot472\`), GDScript puro.
- Única cena: `src/scenes/main.tscn` mínima; TODO o resto é construído em código.
- **Autoloads (nesta ordem):**
  - `EventBus` — sinais globais (shake_requested, inventory_changed, game_over…)
  - `BoardGrid` — modelo lógico do grid (13×15, célula 2×2u), ocupação, BFS
    `compute_reachable`/`find_path`, linha de visão `has_line_of_sight`
  - `DiceManager` — D4/D6/D8/D12/D20/D100 + parser "NdM+K", crítico/falha
  - `TurnManager` — ordem fixa Cavaleiro→Guerreiro→Arqueiro→Boss, fases
    MOVIMENTO/AÇÃO, round_num, game_ended
  - `CombatSystem` — resolução D20 vs CA, crits, bônus de runa, aggro em área
  - `InventorySystem` — itens, equipamento, aplicação de stats no portador
- Classes centrais: `BoardBuilder` (masmorra procedural do MAP ASCII),
  `TacticalCamera`, `BoardUnit` (+`UnitDefs`, `UnitVisuals`),
  `PlayerController`, `EnemyAI`, `GameHUD`.
- **Sem física de gameplay**: unidades são MeshInstance3D posicionadas por grid.
  A única física é a colisão da câmera (paredes em layer 2).

## 4. MECÂNICAS (COMPLETAS)

### Turnos
Ordem fixa por unidade. Cada turno: 1 movimento opcional + 1 ação principal
(atacar / habilidade / defender / item / passar). Teclas [1]–[5].

### Movimento
- **Herói:** rola um D6 de movimento → 1–2 = 3 casas, 3–6 = 6 casas.
  Movimento ortogonal, BFS desviando de peças.
- **Inimigos: valor FIXO por design** (guerreiro 4, arqueiro 3, boss 3) —
  nunca rolam dados de movimento (regra do projeto).

### Combate
- Atacar = D20 + bônus de ataque vs CA (classe de armadura).
- Natural 20 = crítico (dano dobrado nos dados); natural 1 = falha automática.
- **Defender**: +4 de CA até o próximo turno.
- **Runas** ('r' no chão da sala do boss): atacante em cima ganha +2 de dano.

### Fichas de personagem
| Unidade | HP | CA | Ataque | Dano | Notas |
|---|---|---|---|---|---|
| Cavaleiro Ancestral (herói) | 40 | 16 (+2 anel) | +5 (+1 espada) | 1d8+3 | MP 10, regen +2/turno |
| Goblin Guerreiro | 15 | 10 | +2 | 1d6+1 | corpo a corpo |
| Goblin Arqueiro | 12 | 10 | +3 | 1d6 | alcance 5 |
| Cavaleiro Ancestral Sombrio (boss) | 90 | 18 | +5 | 1d12+4 | ver habilidades |

- Habilidade do herói: **Golpe Poderoso** — 2d8+3, custa 3 MP.
- Boss usa pesos fixos por ataque: normal 55% · **Golpe Pesado** 15% (1d12+6) ·
  **Lâmina Sombria** 15% (2d8+4) · **Escudo Sombrio** 15% (só abaixo de metade
  do HP, dá +CA).

### IA e percepção
- Inimigos começam **de guarda**; acordam ao ver o herói (visão 6/7/9 células +
  linha de visão real) ou ao serem atacados (vítima + aliados num raio de 2
  acordam juntos — "te avistou!").
- Acordados, perseguem para sempre: `_step_toward()` escolhe via BFS a célula
  alcançável mais próxima do herói (progresso garantido, sem travar nem
  sobrepor peças); arqueiro reposiciona para melhor célula COM linha de visão.

### Itens e exploração
- Baú amarelo ('C'): Poção de Cura (+10 HP) e Anel de Proteção (+2 CA).
- Inventário modal ([4]); equipar/usar consome a ação principal.
- Névoa de guerra por sala; salas revelam ao entrar (EventBus).

### Feedback (juice)
Popup animado do dado, números flutuantes de dano, flash vermelho no hit,
queda+fade na morte, shake de câmera proporcional ao impacto/crítico.

### Câmera (v0.2.2) — TacticalCamera
Hierarquia: raiz (pan) → Pivot (yaw/pitch) → SpringArm3D (zoom+colisão) → Camera3D.
- **Arrastar botão ESQUERDO**: orbitar 360° horizontal + vertical (pitch 25°–75°)
- **Roda**: zoom suave (4 = inspecionar miniatura de perto, 22 = vista tática)
- **Botão do meio arrastando**: pan "pegando a mesa" (escala com o zoom)
- **WASD/setas**: pan com aceleração/desaceleração (inércia real)
- Q/E giram; clique direito sem arrasto cancela mira (limiar 6px separa os gestos)
- Suavização exponencial independente de FPS em todos os eixos;
  SpringArm colide com as paredes (StaticBody3D layer 2 exclusiva)
- Padrão isométrico tático; ângulos baixos = cinematográfico

## 5. CONTROLES DO JOGADOR

```
Esquerda + arrastar ......... orbitar câmera        1 ............ atacar
Roda ........................ zoom                  2 ............ Golpe Poderoso
Meio + arrastar ............. mover mesa            3 ............ defender
WASD / setas ................ pan                   4 ............ inventário
Clique esquerdo ............. selecionar/mover       5 ............ passar turno
Clique direito .............. cancelar mira          ESC .......... cancelar mira
```

## 6. HISTÓRICO — O QUE JÁ FOI FEITO

| Versão | Commit | Conteúdo |
|---|---|---|
| v0.1.0 | `e0a31c7` | Slice vertical completa: masmorra 3 salas, 4 unidades, turnos, dados, combate, inventário, HUD, IA, névoa, boss, vitória/derrota, bot `--demo` |
| v0.1.1 | — | Percepção/aggro (visão + LOS + alerta em área), rebalance (boss 120→90 HP, herói atk 3→5, runas +2) |
| v0.1.2 | `629d5c4` | Correção crítica: inimigos não recebiam `moves_left` desde v0.1.0; IA reescrita com perseguição determinística |
| v0.1.3 | `352234e` | Primeira câmera orbital (Q/E + botão do meio) |
| v0.1.4 | `98a37bb` | Rotação por mouse (arrasto direito), clique vs arrasto 6px |
| v0.2.0 | `ea08ad5` | Câmera reescrita: órbita esférica total, pitch, zoom cinematográfico, pan relativo |
| v0.2.1 | `4d6c3b9` | Suavização desacoplada por eixo (órbita k=5, zoom k=6, pan k=8) |
| v0.2.2 | `8bc583d` | **TacticalCamera adotada** (Pivot+SpringArm3D, estilo BG3/Solasta), colisores físicos nas paredes (layer 2), pan com inércia |

Infraestrutura: repo público **https://github.com/FalconiRod/Little-Sword**
(branch main); backup local `D:\PROJETOS\BACKUPS\Little-Sword_v0.1.4_2026-08-21.zip`
(16 MB); 111 screenshots reais capturados via Movie Maker (`screenshots/`,
com `.gdignore`); documentação viva em `docs/` (incl. `AI_MEMORY/`).

Bugs históricos resolvidos (detalhes em `docs/AI_MEMORY/BUG_MEMORY.md`):
BUG-001 inimigos sem movimento (moves_left), BUG-002 itens não aplicavam stats
(apply_to_unit órfão), BUG-003 pitfall GDScript `:=` com Variant (recorrente),
BUG-004 cache de classes globais exige `--import` após criar class_name novo.

## 7. ESTADO ATUAL (agosto/2026)

- Demo completa, estável, validada headless com 0 erros (boot + demo + órbita).
- Câmera nova recém-integrada; controles finais idênticos à tabela da seção 5.
- Nada pendente de validação; árvore limpa e publicada no GitHub.

## 8. ROADMAP — O QUE FAZER (ordem sugerida)

### Curto prazo (polir a demo)
1. **Foco por duplo-clique** numa miniatura usando `set_focus()`/`focus_on()`.
2. Presets de câmera (F1 tático / F2 cinema / F3 topo) via `set_zoom_target()`.
3. Cutscene de abertura: câmera desce cinematográfica até a visão tática.
4. Indicador visual de alcance dos arqueiros/boss quando em mira.
5. SFX/Música procedurais (AudioStreamGenerator) — projeto ainda é mudo.

### Médio prazo (conteúdo)
6. 2–3 mapas novos no BoardBuilder (MAP é só um Array de strings).
7. Mais classes de herói (mago com MP ofensivo, clérigo curandeiro).
8. Novos inimigos (cavaleiro esqueleto, necromante invocador).
9. Sistema de loot expandido (raridades, slots de equipamento).
10. Nível de experiência + progressão entre combates.

### Longo prazo (produto)
11. Menu principal, seleção de mapa, opções (sensibilidade da câmera etc.).
12. Save/load (Resource serializando BoardGrid + unidades).
13. Modo hot-seat 2 jogadores (herói vs mestre controlando monstros).
14. Export Windows/Linux + página itch.io; GitHub Actions validando build.

## 9. REGRAS E CONVENÇÕES DO PROJETO (OBRIGATÓRIAS)

1. Tudo em `D:\PROJETOS\Little sword`; backups em `D:\PROJETOS\BACKUPS\`.
2. Zero assets externos; zero cenas além de main.tscn; zero física de gameplay.
3. Inimigos NUNCA rolam movimento (valores fixos) — decisão de design.
4. Sem comentários desnecessários; comentários explicam INTENÇÃO, não sintaxe.
5. Commits: `-c user.name="AI Factory" -c user.email="factory@local"`; push no main.
6. Toda versão atualiza CHANGELOG.md, FEATURES/CURRENT_STATE e memórias de IA.
7. Comunicação em PT-BR: ANÁLISE / PLANO / ALTERAÇÕES / RESULTADO / PRÓXIMOS PASSOS.
8. Validar SEMPRE antes de commit: boot headless 0 erros + demo `--demo` 0 erros.
9. Pitfall GDScript 4: `:=` não infere tipo de comparação/acesso Variant —
   tipar explicitamente (`var x: bool = ...`, `var c := Vector2i(...)`).
10. Após criar class_name NOVO, rodar `--headless --import` antes de validar.

## 10. COMANDOS DE VALIDAÇÃO (PowerShell)

```powershell
$g = "D:\PROJETOS\_tools\godot472\Godot_v4.7.2-stable_win64_console.exe"
# Boot limpo (procura por ERROR):
& $g --headless --path "D:\PROJETOS\Little sword" --quit-after 300
# Demo autônoma (bot joga sozinho):
& $g --headless --path "D:\PROJETOS\Little sword" --quit-after 2500 ++ --demo
# Showcase orbital:
& $g ... ++ --demo --orbit
# Screenshots reais (exe sem console):
& "...\Godot_v4.7.2-stable_win64.exe" --path . --write-movie "screenshots\frame.png" `
  --fixed-fps 20 --quit-after 120 ++ --demo --orbit
```

---
*Gerado em 2026-08-21 · v0.2.2 · commit `8bc583d` · FalconiRod/Little-Sword*
