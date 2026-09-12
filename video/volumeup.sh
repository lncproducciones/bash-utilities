#!/bin/bash

# ==============================================================================
# Nombre: volumeup.sh
# Descripción: Normaliza el volumen de un video usando ffmpeg.
#              Se auto-instala globalmente en /usr/local/bin tras su primera ejecución.
# Autor: Nelson Ochoa.
# ==============================================================================

TARGET_PATH="/usr/local/bin/volumeup.sh"
SCRIPT_PATH="$(readlink -f "$0")"
ORIGEN="$1"
DESTINO="$2"
USANDO_TEMPORAL=0

# ------------------------------------------------------------------------------
# Función de Ayuda (-h / --help)
# ------------------------------------------------------------------------------
mostrar_ayuda() {
    echo ""
    echo "Uso: volumeup.sh [OPCIONES] <archivo_origen> [archivo_destino]"
    echo ""
    echo "Descripción:"
    echo "  Normaliza el volumen del audio de un video aplicando el filtro 'loudnorm'"
    echo "  de ffmpeg sin re-codificar el video."
    echo ""
    echo "Parámetros:"
    echo "  <archivo_origen>   Ruta al archivo de video inicial."
    echo "  [archivo_destino]  (Opcional) Ruta del video procesado. Si se omite,"
    echo "                     se modificará el archivo original directamente."
    echo ""
    echo "Opciones:"
    echo "  -h, --help         Muestra este mensaje de ayuda y finaliza."
    echo "  --about            Muestra información del creador del script."
    echo "  --install          Instala globalmente el script para ser utilizado en todo el sistema"
    echo ""
    echo "Ejemplos:"
    echo "  volumeup.sh entrada.mp4 salida.mp4   # Guarda el resultado en un nuevo archivo"
    echo "  volumeup.sh entrada.mp4              # Reemplaza el archivo original"
    echo "  volumeup.sh --help                   # Muestra ayuda"
    echo "  sudo volumeup.sh --install           # Instala globalmente el script"
    echo ""
}

mostrar_about() {
    clear
    echo ""
    echo "    volumeup.sh"
    echo "    ***********"
    echo ""
    echo "    Normaliza el volumen de un video aplicando el filtro 'loudnorm'"
    echo "    de ffmpeg sin re-codificar el video."
    echo ""
    echo "    Autor:     Nelson Ochoa."
    echo "    Github:    https://github.com/lncproducciones"
    echo ""
    echo "    Más utilidades en https://github.com/lncproducciones/bash-utilities"
    echo ""
}

instalar() {
    clear
    echo ""
    if [ "$EUID" -ne 0 ]; then
        echo "    Error: Para hacer el script accesible globalmente por primera vez,"
        echo "    por favor ejecútalo con sudo: sudo bash $0 ..."
        exit 1
    fi

    echo "    --> Instalando script globalmente en $TARGET_PATH..."
    cp "$SCRIPT_PATH" "$TARGET_PATH"
    chmod +x "$TARGET_PATH"
    
    # Enlace simbólico para comodidad (permite usar 'volumeup' o 'volumeup.sh')
    ln -sf "$TARGET_PATH" /usr/local/bin/volumeup 2>/dev/null
    echo "    --> Script instalado globalmente. Ahora puedes usar 'volumeup.sh' o 'volumeup' desde cualquier carpeta."
    echo ""
}

# Evaluar si solicitó ayuda
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    mostrar_ayuda
    exit 0
fi

if [ "$1" = "--about" ]; then
    mostrar_about
    exit 0
fi

if [ "$1" = "--install" ]; then
    instalar
    exit 0
fi

# ------------------------------------------------------------------------------
# 6.3. Auto-instalación global (copiar a /usr/local/bin si no está ahí)
# ------------------------------------------------------------------------------

if [ "$SCRIPT_PATH" != "$TARGET_PATH" ]; then
    if [ "$EUID" -ne 0 ]; then
        echo "Error: Para hacer el script accesible globalmente por primera vez,"
        echo "por favor ejecútalo con sudo: sudo bash $0 ..."
        exit 1
    fi

    echo "--> Instalando script globalmente en $TARGET_PATH..."
    cp "$SCRIPT_PATH" "$TARGET_PATH"
    chmod +x "$TARGET_PATH"
    
    # Enlace simbólico para comodidad (permite usar 'volumeup' o 'volumeup.sh')
    ln -sf "$TARGET_PATH" /usr/local/bin/volumeup 2>/dev/null
    echo "--> Script instalado globalmente. Ahora puedes usar 'volumeup.sh' o 'volumeup' desde cualquier carpeta."
    echo ""
fi

# ------------------------------------------------------------------------------
# 6.1 y 6.2. Comprobar e instalar ffmpeg
# ------------------------------------------------------------------------------
if ! command -v ffmpeg &> /dev/null; then
    echo "ffmpeg no está instalado."
    
    if [ "$EUID" -ne 0 ]; then
        echo "Error: ffmpeg no está instalado. Debe ejecutar este script como sudo la primera vez para instalar ffmpeg."
        exit 1
    fi

    echo "Instalando ffmpeg mediante apt..."
    apt-get update && apt-get install -y ffmpeg

    if ! command -v ffmpeg &> /dev/null; then
        echo "Error: Falló la instalación de ffmpeg."
        exit 1
    fi
fi

# ------------------------------------------------------------------------------
# 3. Validar si no se proporcionaron parámetros
# ------------------------------------------------------------------------------
if [ -z "$ORIGEN" ]; then
    echo "Error: No se especificación archivo de origen."
    echo ""
    mostrar_ayuda
    exit 1
fi

# Validar si el archivo de origen existe
if [ ! -f "$ORIGEN" ]; then
    echo "Error: El archivo de origen '$ORIGEN' no existe."
    exit 1
fi

# ------------------------------------------------------------------------------
# 5. Manejo de archivo destino ausente (Crear archivo temporal)
# ------------------------------------------------------------------------------
if [ -z "$DESTINO" ]; then
    DIR_ORIGEN="$(dirname "$ORIGEN")"
    EXTENSION="${ORIGEN##*.}"
    DESTINO="$(mktemp "${DIR_ORIGEN}/temp_vol_XXXXXX.${EXTENSION}")"
    USANDO_TEMPORAL=1
else
    # 4. Validar si el archivo de destino existe y pedir confirmación
    if [ -f "$DESTINO" ]; then
        read -p "El archivo de destino '$DESTINO' ya existe. ¿Desea sobrescribirlo? (s/n): " RESPUESTA
        case "$RESPUESTA" in
            [sS]|[sS][eE][sS])
                echo "Sobrescribiendo..."
                ;;
            *)
                echo "Operación cancelada por el usuario."
                exit 0
                ;;
        esac
    fi
fi

# ------------------------------------------------------------------------------
# 6.4. Ejecución del proceso ffmpeg
# ------------------------------------------------------------------------------
echo "Procesando audio de '$ORIGEN'..."
ffmpeg -i "$ORIGEN" -filter:a "loudnorm" -c:v copy "$DESTINO"

# Si finaliza con éxito y se usó un archivo temporal, reemplazar el original
if [ $? -eq 0 ]; then
    if [ $USANDO_TEMPORAL -eq 1 ]; then
        mv "$DESTINO" "$ORIGEN"
        echo "Proceso completado exitosamente. Archivo original actualizado: '$ORIGEN'"
    else
        echo "Proceso completado exitosamente. Archivo guardado en: '$DESTINO'"
    fi
else
    echo "Error: Ocurrió un fallo durante la ejecución de ffmpeg."
    if [ $USANDO_TEMPORAL -eq 1 ] && [ -f "$DESTINO" ]; then
        rm -f "$DESTINO"
    fi
    exit 1
fi