
### SOL-012 — Modelos IA pesados para tempo real (retopologia)
- PROBLEMA: GLBs de ferramentas IA vem com 1-2 MILHOES de tris; tile do chao x 840 casas = ~830M tris/frame = jogo travado (RX580).
- CAUSA: qualidade "render final", nao tempo real.
- SOLUCAO: pipeline glTF-Transform: weld -> simplify --ratio R --error E. O --error padrao (0.0001) mal reduz; usar 0.01-0.02 p/ agressivo. Tile 987k->7k tris; personagens ~19k. meshopt/quantizacao primeiro via copy+deq.cjs.
- ARQUIVOS: src/assets/*.glb (originais em D:\PROJETOS\BACKUPS\little_sword_glb_orig)
- EFEITO: jogo fluido; visual quase igual em peca pequena.
- DATA: 2026-08-23
