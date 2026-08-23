# ROADMAP — Little Sword v0.9.8 → adiante
Registrado em 2026-08-23 a partir do roteiro do usuário. Parte do estado REAL
(v0.1.0→v0.9.8, decisões D14–D17). Cada item é ADIÇÃO sobre a base atual.

## 0. REGRA PERMANENTE DE PIPELINE DE ASSETS (bloqueante, não sugestão)
Todo modelo 3D novo antes de entrar no jogo:
1. weld + simplify (gltf-transform), --error 0.01 (nunca o padrão 0.0001);
   meta: milhares de tris, não milhões.
2. Texturas máx 1024px (textura 8192² = 358MB VRAM sozinha).
3. Se usar EXT_meshopt_compression / KHR_mesh_quantization → converter p/
   float32 (copy + deq.cjs) — este Godot falha em silêncio (BUG-024).
4. Normalizar por AABB (pés y=0, centro, altura-alvo por peça) — nunca à mão.

## 1. BUG câmera girando descontrolada (diagnóstico revisado p/ TacticalCamera real)
Verificar nesta ordem:
1. Conflito entre rotação esquerda(órbita)/direita(yaw) simultâneas ou clique
   rápido interpretado como o outro botão.
2. Sensibilidade (-/=) sem clamp — aceita valores extremos; clampar faixa segura.
3. Lag/follow competindo com órbita manual no mesmo frame (soma de ajustes).
4. Recálculo de max_horizon/zoom_max ao trocar mapa/andar tocando yaw/pitch.
5. Rede de segurança: clamp(min(delta,0.05)) na suavização + teto de variação
   de yaw/pitch por frame.

## 2. Dados físicos 3D na mesa (opcional)
DiceManager continua autoridade; RigidBody3D só espetáculo (impulso+torque),
label quando velocidade < limiar. Detalhes: prompt-dados-fisicos-3d.md.

## 3. Destruição de props + superfícies (opcional)
Troca de mesh estático + partículas, sem rig. SurfaceEffectType por célula
(NONE/WET/OIL/FIRE), propagação BFS reaproveitando pathfinding.
Ref: prompt-props-obstaculo-battlemat.md.

## 4. Movimento "hop" — CONFIRMAR desejo antes
Polish atual (lunge, sombra fake, anel, destaque sutil v0.2.12–16) pode já
cobrir a sensação de peso. Confirmar se vale antes de implementar.

## 5. Modo narrativa (visual novel) + transição p/ combate
DialogueDefinition, cena 2D fora de combate, transição "desenrolar battlemat".
Adição nova, sem urgência técnica.

## 6. Battlemats colecionáveis — visão futura, apenas não bloquear arquitetura.

## 6-MECÂNICAS D&D ESSENCIAIS
- 6-A Iniciativa: d20+DEX por combate, ordem desc, empate por DES base,
  mostrar rolagens.
- 6-B Economia de ações: 1 Movimento + 1 Ação + 1 Bônus + 1 Reação
  (has_action/has_bonus_action/has_reaction/has_movement, reset no início do
  turno). Oportunidade consome Reação do inimigo (hook pré-movimento).
- 6-C Vantagem/Desvantagem: parâmetro NORMAL/ADVANTAGE/DISADVANTAGE em
  roll_attack no DiceManager (não função separada); mostrar as duas rolagens;
  gatilhos: alvo Prone=van, atacante Prone=desv, cobertura consulta igual.
- 6-D Saving Throws: resolve_saving_throw(unit, attribute, dc) genérico;
  CD = 8 + prof + mod do lançador.

## FASES
- FASE 1: checklist seção 0 retroativa nos 6 tripo_*_meshopt.glb pendentes.
- FASE 2: diagnosticar/corrigir bug da câmera (seção 1).
- FASE 3: confirmar com usuário alinhamento fino/facing ranger/alturas.
- FASE 4 (opcional): dados físicos / superfícies / hop (se confirmado).
- FASE 5: modo narrativa quando priorizado.
Parar e reportar (ANÁLISE/PLANO/ALTERAÇÕES/RESULTADO/PRÓXIMOS PASSOS) ao fim
de cada fase.
