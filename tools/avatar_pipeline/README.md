# Pipeline do avatar (Blender)

Gera o avatar masculino 3D pré-renderizado do Moovz Dash em camadas (`body`, `pants`, `shoes`, `shirt`, `hair`) e monta os spritesheets usados em `lib/game/avatar/`. O modelo é original e montado por script, sem assets de terceiros.

## Requisitos

- Blender 4.2 ou mais novo (usa `BLENDER_EEVEE_NEXT`, roda em modo `-b`, sem janela).
- `python3` do sistema com Pillow e numpy (o Python do Blender não precisa de Pillow).
- Cerca de 60 MB livres na pasta de renders intermediários; o Blender usa menos de 300 MB de RAM.

## Como rodar

```bash
tools/avatar_pipeline/run_pipeline.sh --blender /caminho/do/blender
```

Isso faz três passos:

1. `render_layers.py` (dentro do Blender) monta a cena com `build_avatar.py`, posa o boneco quadro a quadro com `animations.py` e renderiza cada camada mais um render completo (`full`) em `--raw` (padrão `${TMPDIR:-/tmp}/avatar_pipeline/<variante>`). Também renderiza as poses em alta resolução.
2. `assemble_spritesheets.py` (Python do sistema) reduz os quadros (supersampling 2x), corrige o alfa das bordas entre camadas e grava as tiras em `assets/map/anim/avatar/` e as poses em `tools/avatar_pipeline/poses/`.
3. `inspect_sprites.py` confere o contrato (tamanho, RGBA, arquivos não vazios, quadros vazios, bordas, frestas) e gera folhas de contato em `<raw>/preview` (ampliadas 3x sobre fundo escuro e laranja claro, versão 64 px como no jogo e a emenda dos loops). Sai com código 1 se achar problema. Os "buracos fechados" listados são informativos (incluem vãos legítimos, como entre braço e tronco); o que garante a ausência de frestas é o erro de alfa e cor contra o render completo, impresso na montagem.

Leva uns 10 minutos (cerca de 700 renders de 256 px). Opções úteis:

| Opção | Uso |
|---|---|
| `--variant NOME` | gera outra variante definida em `avatar_config.json` |
| `--layers shirt` | gera só algumas camadas |
| `--animations idle,run` | renderiza só algumas animações (não grava as outras); por exemplo `--animations slide --skip-poses` gera só `*_default_slide.png` |
| `--sprites-dir DIR` / `--poses-dir DIR` | grava em outro lugar (bom para testar sem mexer nos assets) |
| `--preview-dir DIR` | onde ficam as folhas de contato |
| `--skip-render` | reaproveita os renders de `--raw` e só remonta |
| `--skip-poses` | não renderiza as poses 512x512 |
| `--model-blend ARQ` | usa um modelo externo (ver abaixo) |

Para inspecionar a cena no Blender:

```bash
blender -b --factory-startup -P tools/avatar_pipeline/build_avatar.py -- --save /tmp/avatar.blend
```

## Contrato dos arquivos

- Pasta `assets/map/anim/avatar/`, nome `{camada}_{variante}_{animacao}.png`, por exemplo `shirt_default_run.png`.
- Camadas, na ordem de desenho: `body`, `pants`, `shoes`, `shirt`, `hair` (igual a `AvatarLayer`).
- Cada arquivo tem uma linha de quadros de 128x128 px (largura = quadros x 128, altura 128), RGBA com fundo transparente, personagem olhando e correndo para a direita.
- Animações (iguais a `AvatarAnimation`): `idle` 18 (loop), `run` 16 (loop), `jump` 16, `doubleJump` 16, `deathPit` 24, `deathFaint` 24, `slide` 16 (loop; deslize de corredor, tronco inclinado para trás, uma perna estendida à frente e a outra dobrada, corpo baixo com a base na linha 125 do quadro).
- Mesma câmera e enquadramento em todas as animações: a sola fica na linha 125 do quadro em `idle`/`run` (o jogo desenha o quadro em 64x64 com âncora no centro, e a base do quadro coincide com a base da hitbox do jogador). O personagem em pé ocupa cerca de 114 px de altura (sobra espaço no topo para os braços erguidos do pulo) e fica centrado na coluna 64.
- As 5 camadas sobrepostas em ordem reproduzem o render completo. Cada camada é renderizada com as camadas de baixo como holdout (máscara) e sem as de cima; depois o alfa das bordas onde uma camada de baixo tapa uma de cima é corrigido para que a soma bata com o render completo (sem frestas nem halos). O erro máximo aparece no log da montagem.
- Poses em `tools/avatar_pipeline/poses/`: `idle.png`, `run.png`, `jump.png`, `celebrate.png`, 512x512, personagem completo, fundo transparente, todas na mesma escala e com os pés na mesma linha.

## Estrutura

| Arquivo | Papel |
|---|---|
| `avatar_config.json` | único lugar com cores, variantes, malha de cada variante, câmera, luz, contorno e lista de animações/poses |
| `build_avatar.py` | monta cena, juntas (empties), malhas por camada, materiais toon, contorno e câmera; também aplica uma pose |
| `animations.py` | poses de cada animação por quadro (Python puro, sem `bpy`) |
| `render_layers.py` | renderiza animação x camada e as poses |
| `assemble_spritesheets.py` | monta as tiras finais e as poses |
| `inspect_sprites.py` | verificação automática e folhas de contato |
| `run_pipeline.sh` | encadeia tudo |

### Esqueleto

Peças rígidas presas a empties (sem skinning). Hierarquia: `root` > `pelvis` > (`spine` > `neck` > `head`, `shoulder_X` > `elbow_X` > `wrist_X`) e (`hip_X` > `knee_X` > `ankle_X`), com `X` = `R` (lado da câmera) ou `L`. O personagem olha para +X, a câmera fica no lado -Y.

Cada objeto de malha tem as propriedades `avatar_layer` (camada) e `avatar_joint` (junta) e fica na coleção `avatar_<camada>`.

Canais de pose em `animations.py` (graus): `root.x`, `root.z`, `root.pitch`, `root.pivot`, `root.scale`, `root.lift`, `root.center` (0 a 1: recentraliza o corpo em `root.x`, usado no giro do `doubleJump`); `pelvis|spine|neck|head.pitch/yaw/roll`; `spine.stretch`; `shoulder_X.swing/spread/twist`; `elbow_X.bend`; `wrist_X.bend`; `hip_X.swing/spread`; `knee_X.bend`; `ankle_X.bend`; `face.blink` (0 a 1). `swing` positivo leva o membro para a frente, `bend` positivo dobra a articulação no sentido natural e `pitch` positivo inclina para a frente. A função `plant()` calcula o tornozelo para o pé ficar com a inclinação desejada. Cada pose também diz o modo de chão: `feet` (o pé mais baixo encosta na linha de base mais `root.lift`), `body` (o ponto mais baixo do corpo encosta) ou `None` (usa `root.z` direto, como no `deathPit`).

## Nova variante de roupa por cor

1. Em `avatar_config.json`, dentro de `variants.<camada>`, crie uma entrada com a mesma malha e outras cores, por exemplo:

   ```json
   "azul": {"mesh": "tshirt", "colors": {"fabric": "#2F6FD6", "trim": "#1F4FA0"}}
   ```

2. Rode `run_pipeline.sh --blender ... --variant azul`. Só as camadas que definem `azul` são gravadas (`shirt_azul_*.png`); as outras camadas usam a variante `default` como máscara.
3. No jogo, use `AvatarLayerStyle(variant: 'azul')` para a camada. Para testes rápidos dá também para tingir em tempo de execução com `tint`, sem gerar arquivos.

Já existem dois exemplos no config: `shirt/azul` (cor) e `shirt/regata` (malha). Eles não são gerados por padrão.

## Nova variante de roupa por malha

1. Em `build_avatar.py`, escreva uma função `build_<camada>_<nome>(rig)` que cria as peças com `rig.part(camada, nome, malha, junta, chave_de_cor)`. Use os geradores `loft_mesh`, `capsule_mesh` e `ellipsoid_mesh` e as posições de `rig.rest[junta]`.
2. Registre a função em `MESH_BUILDERS[camada]["<nome>"]`.
3. Crie a variante no config com `"mesh": "<nome>"` e as chaves de cor que a função usa.
4. Rode o pipeline com `--variant`.

Cuidado: uma camada é renderizada com as camadas de baixo como máscara. Se a nova peça cobre partes que a peça padrão não cobria, tudo certo. Se ela expõe algo que estava escondido por uma camada de baixo (por exemplo, um tênis de cano baixo deixando aparecer uma meia que não existe), a parte exposta fica vazia; nesse caso gere também a camada de baixo com uma variante própria. Peças de cima (como a regata) não têm esse problema, porque as camadas de baixo são renderizadas inteiras.

## Trocar o avatar inteiro

Opção 1, procedural: mude as funções `build_*` (ou as proporções em `joint_table()`, `HEAD_CENTER`, `HEAD_RADII`) e rode o pipeline. As animações continuam funcionando porque usam só os nomes das juntas.

Opção 2, modelo externo (`--model-blend arquivo.blend`):

- Modele em pose de repouso (em pé, braços para baixo, olhando para +X, pés em z = 0).
- Cada peça rígida é um objeto de malha com as propriedades `avatar_layer` (uma das 5 camadas) e `avatar_joint` (nome da junta que a move).
- Opcional: empties com a propriedade `avatar_joint` marcam a posição de cada junta; os que faltarem usam as posições de `joint_table()`.
- Materiais com nome `avatar:<chave>` (por exemplo `avatar:fabric`) são trocados pelo material toon com a cor da variante; os outros são mantidos. `avatar_outline = 0` desliga o contorno de uma peça e `avatar_blink = 1` marca os olhos.
- Rode o pipeline com `--model-blend`. Câmera, camadas, animações e montagem são as mesmas.

## Ajustes visuais

- Câmera: `camera.azimuth_deg` (giro 3/4), `camera.elevation_deg`, `standing_height_px` (altura em pé) e `baseline_px` (linha da sola). A escala é calibrada no quadro 0 do `idle`.
- Luz toon: direções `key_light` e `fill_light`, faixa de sombra (`band`, `band_softness`), multiplicador de sombra e de brilho. A iluminação é calculada no shader (sem sombras projetadas).
- Contorno: `outline.thickness` (em metros; 0 desliga) e `outline.color`.

## Imagens estáticas com o avatar

`compose_images.py` (Python do sistema, Pillow e numpy) monta, a partir das poses, as imagens de `assets/images/` que mostravam o passarinho:

- `auto_run_instruction.png`: feita do zero com a pose `run`, linhas de velocidade laranja e sombra no chão.
- `dash_wins.png`: mantém troféu, coroa de folhas e ilha da imagem atual, apaga o personagem acima da coroa (todo pedaço conectado que passa acima da linha 45) e coloca a pose `celebrate` sobre o troféu, com brilhos.

```bash
python3 -I tools/avatar_pipeline/compose_images.py
```

Lê e grava em `assets/images/` mantendo tamanho e modo de cada arquivo. Pode rodar de novo depois de regerar as poses: o resultado é o mesmo, porque o avatar anterior é apagado antes. Use `--out-dir DIR` para gerar prévias sem mexer nos assets, `--source-dir DIR` para partir de outra cópia e `--poses-dir DIR` para usar outras poses. O script para com erro se o personagem encostar no troféu ou na coroa, porque aí não daria para apagá-lo numa próxima rodada.

## Limitações

- O jogo desenha o quadro de 128 px em 64 px sem filtro (vizinho mais próximo), então detalhes menores que 2 px no quadro de 128 podem sumir; o preview `*_64px_*` simula isso.
- No `deathPit` o personagem sai pela base do quadro de propósito; os últimos quadros ficam quase vazios.
- Variantes por malha seguem a regra de máscara descrita acima.
