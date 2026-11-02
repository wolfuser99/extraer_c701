# Xiaomi Smart Camera C701 — Extracción de grabaciones desde microSD

## 1. Objetivo

Extraer las grabaciones almacenadas en la tarjeta microSD de una cámara Xiaomi Smart Camera C701 directamente desde macOS, sin depender de Xiaomi Home, y organizarlas por día sin dividir los archivos originales.

## 2. Problema detectado

La tarjeta contiene distintos tipos de archivos:

- `video_*.mp4`: grabaciones que se pueden reproducir directamente.
- `zreserved_*.bin`: archivos que parecen contenedores multimedia MP4, aunque tienen extensión `.bin`.
- `pic_*.bin`: archivos auxiliares cuya función no se ha confirmado.

Algunos archivos `zreserved` contienen video y audio reconocibles. Por ejemplo, `ffprobe` detectó códecs HEVC y Opus, con una duración aproximada de 12 minutos y 40 segundos en un archivo de 128 MiB.

Sin embargo, otros archivos `.bin` pueden estar incompletos, dañados o contener estructuras que FFmpeg no logra interpretar como video.

### Error observado

Al procesar `zreserved_0129...bin`, FFmpeg devolvió:

```text
[mpeg4] header damaged
[segment] dimensions not set
Could not write header: Invalid argument
```

Esto detuvo la ejecución del primer script.

También apareció una advertencia de macOS al acceder a `.Spotlight-V100`:

```text
Operation not permitted
```

Esta advertencia corresponde a permisos del sistema y no demuestra que las grabaciones estén dañadas.

## 3. Herramientas utilizadas

- macOS y Terminal.
- `ffmpeg`: transformar las grabaciones completas sin recodificarlas.
- `ffprobe`: identificar pistas y códecs de video.
- `find`: localizar archivos `.mp4` y `.bin`.

Comprobar que FFmpeg está instalado:

```bash
ffmpeg -version
ffprobe -version
```

## 4. Diagnóstico de archivos

Consultar el tipo de archivo:

```bash
file "/Volumes/MJ_CAM/archivo.bin"
```

Inspeccionar su cabecera:

```bash
xxd -l 64 "/Volumes/MJ_CAM/archivo.bin"
```

Consultar códecs, duración y tamaño:

```bash
ffprobe -v error \
  -show_entries format=duration,size \
  -show_entries stream=codec_name \
  -of default=noprint_wrappers=1 \
  "/Volumes/MJ_CAM/archivo.bin"
```

Un archivo con pistas reconocibles no necesariamente está íntegro ni se reproduce correctamente.

## 5. Prueba de extracción

Se comprobó que un archivo `zreserved` podía convertirse en un MP4 reproducible mediante:

```bash
ffmpeg -v warning \
  -i "/Volumes/MJ_CAM/zreserved_0061_9999_0_19691231210000_19691231210000.bin" \
  -t 30 -map 0 -c copy \
  -movflags +faststart \
  "$HOME/Desktop/prueba_zreserved.mp4"
```

La prueba funcionó, confirmando que al menos algunos archivos `.bin` contienen grabaciones recuperables sin recodificación.

## 6. Solución implementada

El script `extraer_c701.sh` se diseñó para:

1. Buscar archivos `.mp4` y `.bin` en `/Volumes/MJ_CAM`.
2. Excluir el directorio `.Spotlight-V100`.
3. Utilizar `ffprobe` para comprobar si hay una pista de video.
4. Transformar cada archivo completo con FFmpeg, sin dividirlo.
5. Continuar con los archivos siguientes cuando uno falla.
6. Registrar errores en `errores_AAAA-MM-DD.log`.
7. Organizar los archivos en una única carpeta por día (`AAAA-MM-DD`).
8. Conservar el nombre original, quitando los prefijos `zreserved_` o `video_`; los archivos `.bin` se guardan como `.mp4`.

### Ubicación de salida

```text
~/Desktop/Rescate_C701/
├── 2026-10-27/
│   ├── 2026-10-27_0001.mp4
│   ├── 0061_9999_0_20261027210000_20261027210000.mp4
│   └── ...
└── errores_2026-10-27.log
```

La carpeta por día se determina primero mediante los metadatos `creation_time`
del video; si no existen, se usa la fecha del nombre original y finalmente la fecha
de modificación del archivo.

El script utiliza `-c copy`, por lo que no recodifica ni divide el video y conserva
la calidad de las pistas que logra extraer.

**Nota:** si la cámara no conserva la fecha y hora en los metadatos o en el nombre
original, el archivo se coloca en la fecha de ejecución y se registra un aviso en
el log.

## 7. Ejecución

Crear y ejecutar el script:

```bash
chmod +x "./extraer_c701.sh"
"./extraer_c701.sh"
```

La tarjeta debe estar montada en `/Volumes/MJ_CAM`. Si macOS le asigna otro nombre, hay que actualizar la variable `ORIGEN` en el script.

## 8. Precauciones

- No borrar ni formatear la tarjeta original hasta verificar los videos extraídos.
- Guardar los resultados en un disco con espacio suficiente.
- Una tarjeta examinada anteriormente llegó a mostrar 116 GiB usados de 116 GiB disponibles, con solo 202 MiB libres.
- La extensión `.bin` no demuestra que el archivo esté cifrado.
- Los errores de FFmpeg no prueban por sí solos que un archivo esté cifrado o sea irrecuperable.
- El script de extracción debe probarse con cada tarjeta: distintas tarjetas pueden contener archivos y estructuras diferentes.

## 9. Pendiente

- Revisar `errores_AAAA-MM-DD.log` para identificar los archivos que no se pudieron procesar.
- Comprobar que todos los archivos transformados se reproduzcan.
- Investigar cómo recuperar las marcas de tiempo reales de los archivos `zreserved`.
- Validar que todos los archivos transformados conserven sus nombres normalizados.
- Confirmar si los archivos auxiliares `pic_*.bin` contienen metadatos útiles para reconstruir el orden de las grabaciones.

## Estado actual

**Extracción parcial comprobada.** Se ha confirmado que algunos archivos `zreserved_*.bin` contienen pistas multimedia recuperables. El procesamiento por lotes está preparado para registrar errores y continuar, pero todavía falta validar la integridad de todos los archivos y reconstruir la cronología completa.
