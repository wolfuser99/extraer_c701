#!/bin/bash

ORIGEN="/Volumes/MJ_CAM"
FECHA=$(date +"%Y-%m-%d")
DESTINO="$HOME/Desktop/Rescate_C701"
LOG="$DESTINO/errores_$FECHA.log"

dia_de_archivo() {
  local archivo="$1"
  local marca dia nombre

  marca=$(ffprobe -v error \
    -show_entries format_tags=creation_time:stream_tags=creation_time \
    -of default=noprint_wrappers=1:nokey=1 \
    "$archivo" 2>/dev/null | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:' | head -1)
  dia=$(printf "%s" "$marca" | sed -nE 's/^([0-9]{4}-[0-9]{2}-[0-9]{2})T[0-9]{2}:.*/\1/p')
  [[ "$dia" == 1969-* ]] && dia=""

  if ! [[ "$dia" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    nombre=$(basename "$archivo")
    if [[ "$nombre" =~ _([0-9]{8})([0-9]{2})[0-9]{4}_ ]] &&
       [ "${BASH_REMATCH[1]}" != "19691231" ]; then
      dia="${BASH_REMATCH[1]:0:4}-${BASH_REMATCH[1]:4:2}-${BASH_REMATCH[1]:6:2}"
    fi
  fi

  if ! [[ "$dia" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    dia=$(stat -f "%Sm" -t "%Y-%m-%d" "$archivo" 2>/dev/null)
  fi

  if ! [[ "$dia" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    dia="$FECHA"
    echo "AVISO: no se pudo determinar la fecha de $archivo; se usará ${dia}" >> "$LOG"
  fi

  printf "%s" "$dia"
}

nombre_de_salida() {
  local nombre="$1"

  nombre="${nombre#zreserved_}"
  nombre="${nombre#video_}"
  if [[ "$nombre" == *.bin ]]; then
    nombre="${nombre%.bin}.mp4"
  fi
  printf "%s" "$nombre"
}

if [ ! -d "$ORIGEN" ]; then
  echo "No encuentro la tarjeta en $ORIGEN"
  exit 1
fi

mkdir -p "$DESTINO"
: > "$LOG"
procesados=0

echo "Buscando archivos de video..."

while IFS= read -r -d '' archivo; do
  # Exigir que ffprobe detecte un códec de video
  codec=$(ffprobe -v error -select_streams v:0 \
    -show_entries stream=codec_name -of csv=p=0 \
    "$archivo" 2>/dev/null | head -1)

  [ -n "$codec" ] || continue

  dia=$(dia_de_archivo "$archivo")
  carpeta="$DESTINO/$dia"
  nombre=$(nombre_de_salida "$(basename "$archivo")")
  salida="$carpeta/$nombre"
  mkdir -p "$carpeta"
  echo "Procesando: $(basename "$archivo") [$codec] -> $dia/$nombre"

  if ffmpeg -nostdin -hide_banner -loglevel error -y \
      -i "$archivo" \
      -map 0 -c copy -movflags +faststart \
      "$salida" 2>>"$LOG"; then
    procesados=$((procesados + 1))
  else
    echo "ERROR: $archivo" >> "$LOG"
    rm -f "$salida"
  fi

done < <(find "$ORIGEN" -type f \( -iname '*.mp4' -o -iname '*.bin' \) \
  -not -path '*/.Spotlight-V100/*' -print0 2>/dev/null)

carpetas=$(find "$DESTINO" -type d -name '????-??-??' | wc -l | tr -d ' ')

echo
echo "Proceso terminado."
echo "Archivos transformados: $procesados"
echo "Carpetas por día: $carpetas"
echo "Errores registrados en: $LOG"
echo "Resultado: $DESTINO"
