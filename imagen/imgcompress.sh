#!/bin/bash

# ==============================================================================
# Nombre: imgcompress.sh
# Descripción: Comprime imágenes PNG/JPG o las convierte a formato WebP.
# Autor: Nelson Ochoa.
# ==============================================================================

TARGET_PATH="/usr/local/bin/imgcompress.sh"
SCRIPT_PATH="$(readlink -f "$0")"

MODO=""
ORIGEN=""
DESTINO=""
USANDO_TEMPORAL=0

# ------------------------------------------------------------------------------
# Funciones de Ayuda, About e Instalación
# ------------------------------------------------------------------------------
mostrar_ayuda() {
    echo ""
    echo "Uso: imgcompress.sh [MODO] <archivo_origen> [archivo_destino]"
    echo ""
    echo "Descripción:"
    echo "  Comprime imágenes JPG/PNG o las convierte al formato optimizado WebP."
    echo ""
    echo "Modos (Opcional, por defecto es --compress):"
    echo "  --compress         Comprime la imagen manteniendo su formato o convirtiendo a WebP."
    echo "  --webp             Convierte la imagen (JPG/PNG) a formato WebP con compresión."
    echo ""
    echo "Parámetros:"
    echo "  <archivo_origen>   Ruta a la imagen inicial (.jpg, .jpeg, .png, .webp)."
    echo "  [archivo_destino]  (Opcional) Ruta del archivo guardado. Si se omite,"
    echo "                     se sobrescribirá el archivo original."
    echo ""
    echo "Opciones generales:"
    echo "  -h, --help         Muestra este mensaje de ayuda y finaliza."
    echo "  --about            Muestra información del creador del script."
    echo "  --install          Instala globalmente el script y sus dependencias."
    echo ""
    echo "Ejemplos:"
    echo "  imgcompress.sh foto.jpg                         # Comprime por defecto (sobrescribe)"
    echo "  imgcompress.sh --compress foto.jpg foto_opt.jpg # Comprime hacia destino"
    echo "  imgcompress.sh --webp foto.png foto.webp        # Convierte a WebP"
    echo "  sudo imgcompress.sh --install"
    echo ""
}

mostrar_about() {
    clear
    echo ""
    echo "    imgcompress.sh"
    echo "    **************"
    echo ""
    echo "    Comprime imágenes y realiza conversiones optimizadas a WebP."
    echo ""
    echo "    Autor:     Nelson Ochoa."
    echo "    Github:    https://github.com/lncproducciones"
    echo ""
    echo "    Más utilidades en https://github.com/lncproducciones/bash-utilities"
    echo ""
}

instalar_dependencias() {
    local DEPS=("magick" "pngquant" "cwebp")
    local FALTANTES=()

    if ! command -v magick &> /dev/null && ! command -v convert &> /dev/null; then
        FALTANTES+=("imagemagick")
    fi
    if ! command -v pngquant &> /dev/null; then
        FALTANTES+=("pngquant")
    fi
    if ! command -v cwebp &> /dev/null; then
        FALTANTES+=("webp")
    fi

    if [ ${#FALTANTES[@]} -gt 0 ]; then
        echo "Faltan las siguientes dependencias: ${FALTANTES[*]}"
        
        if [ "$EUID" -ne 0 ]; then
            echo "Error: Se requieren permisos de superusuario para instalar dependencias."
            echo "Ejecute: sudo bash $0 --install"
            exit 1
        fi

        echo "Instalando dependencias mediante apt..."
        apt-get update && apt-get install -y "${FALTANTES[@]}"
    fi
}

instalar() {
    clear
    echo ""
    if [ "$EUID" -ne 0 ]; then
        echo "    Error: Para instalar el script globalmente,"
        echo "    por favor ejecútalo con sudo: sudo bash $0 --install"
        echo ""
        exit 1
    fi

    instalar_dependencias

    echo "    --> Instalando script globalmente en $TARGET_PATH..."
    cp "$SCRIPT_PATH" "$TARGET_PATH"
    chmod +x "$TARGET_PATH"
    
    ln -sf "$TARGET_PATH" /usr/local/bin/imgcompress 2>/dev/null
    echo "    --> Script e imágenes instalados exitosamente. Puedes usar 'imgcompress.sh' o 'imgcompress' desde cualquier lugar."
    echo ""
}

# ------------------------------------------------------------------------------
# Manejo de Flags Básicos
# ------------------------------------------------------------------------------
case "$1" in
    -h|--help)
        mostrar_ayuda
        exit 0
        ;;
    --about)
        mostrar_about
        exit 0
        ;;
    --install)
        instalar
        exit 0
        ;;
esac

# ------------------------------------------------------------------------------
# Lectura Inteligente de Parámetros de Operación
# ------------------------------------------------------------------------------
if [ "$1" = "--compress" ] || [ "$1" = "--webp" ]; then
    MODO="$1"
    ORIGEN="$2"
    DESTINO="$3"
else
    # Si no se pasó un modo, se usa --compress por defecto
    MODO="--compress"
    ORIGEN="$1"
    DESTINO="$2"
fi

if [ -z "$ORIGEN" ]; then
    echo "Error: No se especificó el archivo de origen."
    mostrar_ayuda
    exit 1
fi

if [ ! -f "$ORIGEN" ]; then
    echo "Error: El archivo de origen '$ORIGEN' no existe."
    exit 1
fi

# Validar/Instalar dependencias si faltan durante la ejecución
instalar_dependencias

# ------------------------------------------------------------------------------
# Manejo de Extensiones y Ajustes de Modo
# ------------------------------------------------------------------------------
EXT_ORIGEN="$(echo "${ORIGEN##*.}" | tr '[:upper:]' '[:lower:]')"

if [[ "$EXT_ORIGEN" != "jpg" && "$EXT_ORIGEN" != "jpeg" && "$EXT_ORIGEN" != "png" && "$EXT_ORIGEN" != "webp" ]]; then
    echo "Error: Formato '.$EXT_ORIGEN' no soportado. Solo se admiten archivos .jpg, .jpeg, .png y .webp"
    exit 1
fi

if [ "$EXT_ORIGEN" = "webp" ]; then
    if [ "$MODO" = "--webp" ]; then
        echo "Aviso: El archivo ya está en formato .webp. Se aplicará solo compresión."
    fi
    MODO="--compress"
fi

# ------------------------------------------------------------------------------
# Manejo del Archivo Destino y Temporales
# ------------------------------------------------------------------------------
if [ -z "$DESTINO" ]; then
    DIR_ORIGEN="$(dirname "$ORIGEN")"
    
    if [ "$MODO" = "--webp" ]; then
        NOMBRE_BASE="$(basename "$ORIGEN" ."$EXT_ORIGEN")"
        DESTINO="${DIR_ORIGEN}/${NOMBRE_BASE}.webp"
    else
        DESTINO="$(mktemp "${DIR_ORIGEN}/temp_img_XXXXXX.${EXT_ORIGEN}")"
        USANDO_TEMPORAL=1
    fi
else
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
# Procesamiento de la Imagen
# ------------------------------------------------------------------------------
CMD_MAGICK="magick"
if ! command -v magick &> /dev/null; then
    CMD_MAGICK="convert"
fi

echo "Procesando '$ORIGEN'..."

if [ "$MODO" = "--webp" ]; then
    cwebp -q 80 "$ORIGEN" -o "$DESTINO"
else
    case "$EXT_ORIGEN" in
        jpg|jpeg)
            $CMD_MAGICK "$ORIGEN" -quality 82 "$DESTINO"
            ;;
        png)
            pngquant --quality=65-80 --force --output "$DESTINO" "$ORIGEN" 2>/dev/null
            if [ $? -ne 0 ]; then
                $CMD_MAGICK "$ORIGEN" -strip -quality 92 "$DESTINO"
            fi
            ;;
        webp)
            cwebp -q 75 "$ORIGEN" -o "$DESTINO"
            ;;
    esac
fi

if [ $? -eq 0 ]; then
    if [ $USANDO_TEMPORAL -eq 1 ]; then
        mv "$DESTINO" "$ORIGEN"
        echo "Proceso completado exitosamente. Archivo actualizado: '$ORIGEN'"
    else
        echo "Proceso completado exitosamente. Archivo guardado en: '$DESTINO'"
    fi
else
    echo "Error: Ocurrió un fallo durante el procesamiento de la imagen."
    if [ $USANDO_TEMPORAL -eq 1 ] && [ -f "$DESTINO" ]; then
        rm -f "$DESTINO"
    fi
    exit 1
fi