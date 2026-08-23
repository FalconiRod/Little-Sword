
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
