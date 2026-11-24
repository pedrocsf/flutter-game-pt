#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

BLENDER="${BLENDER:-blender}"
VARIANT="default"
LAYERS=""
ANIMATIONS=""
RAW_DIR=""
SPRITES_DIR="$REPO_ROOT/assets/map/anim/avatar"
POSES_DIR="$SCRIPT_DIR/poses"
PREVIEW_DIR=""
MODEL_BLEND=""
SKIP_POSES=0
SKIP_RENDER=0

usage() {
  cat <<EOF
Uso: $(basename "$0") [opcoes]
  --blender CAMINHO     executavel do Blender 4.2+ (padrao: \$BLENDER ou 'blender')
  --variant NOME        variante definida em avatar_config.json (padrao: default)
  --layers a,b          camadas a gerar (padrao: todas que definem a variante)
  --animations a,b      subconjunto de animacoes (somente para testes)
  --raw DIR             pasta dos renders intermediarios (padrao: \${TMPDIR:-/tmp}/avatar_pipeline/<variante>)
  --sprites-dir DIR     destino dos spritesheets (padrao: assets/map/anim/avatar)
  --poses-dir DIR       destino das poses 512x512 (padrao: tools/avatar_pipeline/poses)
  --preview-dir DIR     pasta das folhas de contato (padrao: <raw>/preview)
  --model-blend ARQ     .blend com um modelo externo (ver README)
  --skip-poses          nao renderiza as poses em alta resolucao
  --skip-render         reaproveita os renders ja existentes em --raw
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --blender) BLENDER="$2"; shift 2 ;;
    --variant) VARIANT="$2"; shift 2 ;;
    --layers) LAYERS="$2"; shift 2 ;;
    --animations) ANIMATIONS="$2"; shift 2 ;;
    --raw) RAW_DIR="$2"; shift 2 ;;
    --sprites-dir) SPRITES_DIR="$2"; shift 2 ;;
    --poses-dir) POSES_DIR="$2"; shift 2 ;;
    --preview-dir) PREVIEW_DIR="$2"; shift 2 ;;
    --model-blend) MODEL_BLEND="$2"; shift 2 ;;
    --skip-poses) SKIP_POSES=1; shift ;;
    --skip-render) SKIP_RENDER=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opcao desconhecida: $1" >&2; usage; exit 2 ;;
  esac
done

RAW_DIR="${RAW_DIR:-${TMPDIR:-/tmp}/avatar_pipeline/$VARIANT}"
PREVIEW_DIR="${PREVIEW_DIR:-$RAW_DIR/preview}"
mkdir -p "$RAW_DIR" "$SPRITES_DIR" "$PREVIEW_DIR"

if [[ "$SKIP_RENDER" -eq 0 ]]; then
  RENDER_ARGS=(--out "$RAW_DIR" --variant "$VARIANT")
  [[ -n "$LAYERS" ]] && RENDER_ARGS+=(--layers "$LAYERS")
  [[ -n "$ANIMATIONS" ]] && RENDER_ARGS+=(--animations "$ANIMATIONS")
  [[ -n "$MODEL_BLEND" ]] && RENDER_ARGS+=(--model-blend "$MODEL_BLEND")
  [[ "$SKIP_POSES" -eq 1 ]] && RENDER_ARGS+=(--skip-poses)
  echo "[1/3] Renderizando camadas com $BLENDER (log em $RAW_DIR/blender.log)"
  "$BLENDER" -b --factory-startup -P "$SCRIPT_DIR/render_layers.py" -- "${RENDER_ARGS[@]}" > "$RAW_DIR/blender.log" 2>&1 || {
    tail -n 40 "$RAW_DIR/blender.log" >&2
    exit 1
  }
  grep '^\[avatar\]' "$RAW_DIR/blender.log" || true
fi

echo "[2/3] Montando spritesheets em $SPRITES_DIR"
ASSEMBLE_ARGS=(--raw "$RAW_DIR" --sprites-dir "$SPRITES_DIR" --poses-dir "$POSES_DIR")
[[ "$SKIP_POSES" -eq 1 ]] && ASSEMBLE_ARGS+=(--skip-poses)
python3 -I "$SCRIPT_DIR/assemble_spritesheets.py" "${ASSEMBLE_ARGS[@]}"

if [[ -z "$ANIMATIONS" && -z "$LAYERS" && "$VARIANT" == "default" ]]; then
  echo "[3/3] Verificando e gerando previas em $PREVIEW_DIR"
  python3 -I "$SCRIPT_DIR/inspect_sprites.py" --sprites-dir "$SPRITES_DIR" --variant "$VARIANT" --preview-dir "$PREVIEW_DIR"
else
  echo "[3/3] Verificacao completa pulada (execucao parcial ou variante parcial)"
fi
