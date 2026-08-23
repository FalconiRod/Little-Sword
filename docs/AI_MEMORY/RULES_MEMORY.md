
- R-GDSCRIPT-03: Vector3 NAO tem construtor que aceita Array no Godot 4 (`Vector3([1,1,1])` = erro runtime "Nonexistent Vector3 constructor"); usar componentes explicitos. Erros de runtime em funcao chamada NAO abortam o chamador (retorna null e continua) - bugs silenciosos.
- R-PATHS-02: modelos GLB do jogo vivem em res://src/assets/ (ranger.glb, druida.glb, maga/, goblins/, urso transformaçao/), NAO em res://assets/models. user:// real = %APPDATA%\Godot\app_userdata\Little Sword - Tactical Board RPG\.
