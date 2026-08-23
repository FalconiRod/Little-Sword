
### SOL-012 — Modelos IA pesados para tempo real (retopologia)
- PROBLEMA: GLBs de ferramentas IA vem com 1-2 MILHOES de tris; tile do chao x 840 casas = ~830M tris/frame = jogo travado (RX580).
- CAUSA: qualidade "render final", nao tempo real.
- SOLUCAO: pipeline glTF-Transform: weld -> simplify --ratio R --error E. O --error padrao (0.0001) mal reduz; usar 0.01-0.02 p/ agressivo. Tile 987k->7k tris; personagens ~19k. meshopt/quantizacao primeiro via copy+deq.cjs.
- ARQUIVOS: src/assets/*.glb (originais em D:\PROJETOS\BACKUPS\little_sword_glb_orig)
- EFEITO: jogo fluido; visual quase igual em peca pequena.
- DATA: 2026-08-23

### SOL-013 — Freeze na transformacao do druida (texturas 8K)
- PROBLEMA: transformar druida em urso travava o jogo todo.
- CAUSA: texturas 8192x8192 (~358MB VRAM cada, x2 = ~716MB) despejadas no MEIO da partida — urso era a unica peca carregada fora do boot. RX580 + gl_compatibility congela no upload.
- SOLUCAO: resize.cjs (sharp via gltf-transform core) reduz TODAS as texturas dos 8 GLBs para <=1024px; arquivos ficaram <1MB cada. CLI resize tem bug de colourspace — usar script programatico em %TEMP%\opencode\gtt.
- ARQUIVOS: src/assets/**/*.glb; guard anti-AABB-degenerado em _glb_piece.
- DATA: 2026-08-23

### SOL-014 — Tripo meshopt: import falha mesmo apos desquantizar (sub-passos de malha)
- PROBLEMA: GLBs tripo convertidos p/ float32 limpo (sem extensionsRequired) AINDA ficavam valid=false no import de cena, sem erro no log; parse runtime (GLTFDocument) dava ERR=0.
- CAUSA: sub-passos do ResourceImporterScene — geracao de LODs/shadow-meshes/tangentes trava na geometria desses modelos.
- SOLUCAO: editar o .import ANTES/depois do primeiro scan: meshes/generate_lods=false, meshes/create_shadow_meshes=false, meshes/ensure_tangents=false; deletar .import antigo e reimportar.
- RESULTADO: 5 tripo OK (~57-59k tris cada, texturas <=1024, <1.8MB).
- OBS: roteiro falava em 6 tripos; o 54a0992b nao existe mais (removido pelo usuario).
- DATA: 2026-08-23

### SOL-015 — Camera girando descontrolada (drag orfao)
- PROBLEMA: as vezes a camera gira sem controle com qualquer movimento do mouse.
- CAUSA RAIZ: _is_orbiting/_is_orbiting_yaw ligados no PRESS mas so desligados se o RELEASE chegar ao _unhandled_input; release sobre Control do HUD ou fora da janela era consumido/perdido -> flag presa true para sempre.
- SOLUCAO (defesa em profundidade): 1) watchdog por frame valida botao FISICO (Input.is_mouse_button_pressed) e derruba modo orfao; 2) qualquer RELEASE de mouse limpa os dois modos; 3) motion so gira com botao fisico confirmado; 4) clamp delta<=0.05; 5) clamp relative do mouse +-200; 6) teto de velocidade angular yaw 8 rad/s / pitch 6 rad/s por frame.
- ARQUIVOS: src/core/tactical_camera.gd
- SENSIBILIDADE (-/=): ja era clampeada (SENS_MIN/MAX), verificada OK. Follow/zoom-max: nao interferem em rotacao, verificado.
- DATA: 2026-08-23
