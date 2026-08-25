# GLB — Pasta para modelos reais (Seção 11)

> Nesta fase o jogo roda só com primitivas (`BoxMesh`/`CapsuleMesh`). Quando os `.glb` chegarem, **basta apontar** o campo `model_scene` do `Resource` — sem tocar em lógica.

## Onde colocar

```
assets/glb/
├── characters/
│   ├── cavaleiro.glb
│   ├── maga_elara.glb
│   ├── druida_rowan.glb
│   ├── druida_urso.glb      # alternate_form
│   ├── goblin_guerreiro.glb
│   ├── goblin_arqueiro.glb
│   └── boss_ancestral.glb
├── props/
│   ├── muro.glb
│   ├── mureta.glb
│   ├── coluna.glb
│   ├── porta.glb
│   └── decor_*.glb
├── tiles/
│   ├── tile_grama.glb
│   └── tile_pedra.glb
└── houses/
    └── casa_2_andares.glb   # StairsDefinition
```

## Como ativar (1 linha por Resource)

No inspetor do `.tres` ou via código:

- `CharacterDefinition.model_scene = preload("res://assets/glb/characters/cavaleiro.glb")`
- `WallDefinition.model_scene = preload("res://assets/glb/props/muro.glb")`
- `FloorTheme.model_scene = preload("res://assets/glb/tiles/tile_grama.glb")`
- `StairsDefinition.model_scene = preload("res://assets/glb/houses/casa_2_andares.glb")`

O código já faz `if model_scene != null: instanciar GLB senão primitiva` — troca é instantânea.

## Requisitos do GLB (Seção 11)

- **Bounding box** conferido (TILE=2.0 → casa 4×6 = 8×12 unidades)
- **Escala uniforme** (não distorcer em X/Y/Z separados)
- **Origem** no centro da base da célula (para `grid_to_world` coincidir)
- **Poligonagem reduzida** (mobile `gl_compatibility`)
- **Textura ≤1024px**
- **Sem** `meshopt`/`quantização` incompatível com Godot 4.7.2

## Git LFS (opcional)

Se os `.glb` forem >50MB, habilite:

```bat
git lfs track "*.glb"
git add .gitattributes
```

Por enquanto `.gitignore` **não** ignora `*.glb` — já pode commitar direto.
