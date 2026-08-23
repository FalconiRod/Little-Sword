# GUIA DO EDITOR DE MAPAS — para o game designer

Você monta e ajusta o mapa **dentro do próprio jogo**, sem programar nada.
Tudo que você coloca é salvo automaticamente num arquivo de edição e
reaparece sempre que o mapa abrir.

---

## Abrir e fechar
- **F1** abre/fecha o editor. Ao abrir, o HUD do jogador some; ao fechar, volta.
- Enquanto o editor está aberto, os turnos ficam pausados.

## Colocar coisas
1. Escolha um item na **Biblioteca** (pisos/tileset, paredes, obstáculos,
   props ou modelos GLB).
2. Passe o mouse pelo tabuleiro: aparece uma **caixa azul fantasma com o
   nome do asset** na casa onde vai cair.
3. **Clique na casa** para colocar.

## Editar o que já existe (peças SUAS ou do mapa: heróis, goblins…)
- Modo **Selecionar/Mover** → clique na peça ou unidade:
  - **Clique noutra casa livre = mover**
  - **Q / E** = girar 90° · **roda do mouse / sliders** = escala
  - **DEL ou X** = excluir (botão "EXCLUIR o que esta selecionado" também)
- Inimigos podem ser excluídos de vez; heróis só movem/giram.
- Modo **Apagar**: clique no que quer remover (restaura piso original).

## Trocar piso/tileset de uma casa
- Modo **Trocar piso (tileset)** → escolha um piso → clique na casa.
  O tile original some e entra o novo. Para desfazer: modo Apagar na casa.

## Usar seus próprios modelos (.glb)
1. Copie seus arquivos `.glb` para a pasta:
   `D:\PROJETOS\Little sword\src\assets\editor\`
2. No editor, clique em **RECARREGAR ASSETS (.glb)** — não precisa reiniciar.
3. O modelo entra na lista "modelos GLB"; clique nele e depois numa casa.

Dicas: nomes simples sem espaços (`arvore_grande.glb`); qualquer escala é
normalizada para ~1,4 m de altura; use Q/E e a roda para ajustar.

## Spawns (onde cada personagem nasce)
- Seção "spawns": K=cavaleiro, M=mago, W=ranger, g=goblin, a=arqueiro, B=boss.
- Clique no spawn desejado e depois na casa — a marca amarela mostra onde.

## Salvar
- Botão **SALVAR MAPA** grava tudo (validação das portas roda junto).
- O arquivo fica em `%APPDATA%\Godot\app_userdata\Little Sword - Tactical Board RPG\`.
- Sem salvar, as mudanças somem ao fechar o jogo.

## Escada entre andares
- Modo **Escada**: clique na casa de baixo e depois na de cima — cria o par.

---
Qualquer comportamento estranho: anote o que fez e me diga — tem log de
diagnóstico embutido que eu consigo ler.
