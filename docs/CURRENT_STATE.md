# Estado Atual — 2026-08-22 — v0.7.0

## Status: TRANSIÇÃO DE ESCADA CORRIGIDA NA RAIZ + PORTAS VALIDADAS ✅

## O que funciona (validado headless)
- 4 mapas modulares (`stone_keep` 3 andares, `tower`, `house`, `crypt`)
  — carregam sem nenhum warning de configuração
- **Transição de escada em UM clique, com troca visual imediata**: fade +
  andar ativo + câmera sincronizados no próprio evento
  (`_on_unit_changed_floor`); herói nunca fica invisível; sem "piso flutuando"
- **Clicar na casa da escada cruza automaticamente** e desembarca no
  primeiro grid livre à frente (8 direções); esgotadas as saídas, chega
  em pé na própria escada de chegada; só falha se até o par estiver ocupado
- Chegar pelo salto pareado não re-cruza; corredor não cruza;
  re-click re-cruza (custa 1 MP)
- **Regra D14**: portas validadas na carga — eixo de abertura livre dos
  dois lados, sem porta encostada; violação vira warning no console
- Validação do pareamento de escada na carga do mapa
- IA/bot cross-floor via `dist_to_goal`; combate completo (LOS, terreno
  alto, level up, habilidades); retratos clicáveis com fade

## Como jogar / validar
```
godot --path .                                    # editor/PLAY
godot --headless --path . --quit-after 3500 ++ --demo            # bot joga stone_keep
godot --headless --path . --quit-after 6000 ++ --demo ++ --map=tower|crypt|house
godot --headless --path . --quit-after 1500 ++ --clicktest       # => OK
godot --headless --path . --quit-after 1500 ++ --skilltest       # => OK
godot --headless --path . --quit-after 3000 ++ --stairtest ++ --map=tower   # 7/7 => OK
```

## Próximo passo recomendado
1. Prop GLB do Meshy no lugar da espiral procedural (`stairs_prop`)
2. Conteúdo: novos mapas só com ASCII + pares "stairs" (portas já validadas)
3. Combate entre células pareadas (base↔topo) — decidir regra futura
4. Depois: áudio e save

## Pendências conhecidas
- Nenhuma bloqueante. BUG-011..020 resolvidos (ver BUG_MEMORY).
