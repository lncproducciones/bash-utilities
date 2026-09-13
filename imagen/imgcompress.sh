#!/bin/bash

# ==============================================================================
# Nombre: imgcompress.sh
# Descripción: Comprime imágenes PNG/JPG o las convierte a formato WebP.
#              Soporta archivos individuales y carpetas completas.
# Autor: Nelson Ochoa.
# ==============================================================================

TARGET_PATH="/usr/local/bin/imgcompress.sh"
SCRIPT_PATH="$(readlink -f "$0")"

MODO=""
ORIGEN=""
DESTINO=""

# ------------------------------------------------------------------------------
# Funciones de Ayuda, About e Instalación
# ------------------------------------------------------------------------------
mostrar_ayuda() {
    echo ""
    echo "Uso: imgcompress.sh [MODO] <archivo_o_directorio> [archivo_destino]"
    echo ""
    echo "Descripción:"
    echo "  Comprime imágenes JPG/PNG o las convierte al formato optimizado WebP."
    echo "  Permite procesar archivos individuales o directorios completos."
    echo ""
    echo "Modos (Opcional, por defecto es --compress):"
    echo "  --compress         Comprime la imagen manteniendo su formato original."
    echo "  --webp             Convierte la imagen (JPG/PNG) a formato WebP con compresión."
    echo ""
    echo "Parámetros:"
    echo "  <archivo_o_directorio> Ruta a un archivo o a una carpeta (use '.' para actual)."
    echo "  [archivo_destino]      (Opcional, solo para archivo único) Ruta de salida."
    echo ""
    echo "Opciones generales:"
    echo "  -h, --help         Muestra este mensaje de ayuda y finaliza."
    echo "  --about            Muestra información del creador del script."
    echo "  --install          Instala globalmente el script y sus dependencias."
    echo ""
    echo "Ejemplos:"
    echo "  imgcompress.sh foto.jpg                         # Comprime un archivo"
    echo "  imgcompress.sh .                                # Comprime todo el directorio actual"
    echo "  imgcompress.sh --webp .                         # Convierte todo el directorio a .webp"
    echo "  imgcompress.sh --compress /ruta/a/fotos         # Comprime una carpeta específica"
    echo "  sudo imgcompress.sh --install"
    echo ""
}

mostrar_about() {
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
    echo "    --> Script instalado exitosamente. Puedes usar 'imgcompress.sh' o 'imgcompress' desde cualquier lugar."
    echo ""
}

# ------------------------------------------------------------------------------
# Función para Procesar un Archivo Individual
# ------------------------------------------------------------------------------
procesar_archivo() {
    local ARCH_ORIGEN="$1"
    local ARCH_DESTINO="$2"
    local MODO_ACTUAL="$3"
    local USANDO_TEMPORAL=0

    local EXT_ORIGEN
    EXT_ORIGEN="$(echo "${ARCH_ORIGEN##*.}" | tr '[:upper:]' '[:lower:]')"

    # Validar formato
    if [[ "$EXT_ORIGEN" != "jpg" && "$EXT_ORIGEN" != "jpeg" && "$EXT_ORIGEN" != "png" && "$EXT_ORIGEN" != "webp" ]]; then
        return 0 # Ignorar silenciosamente archivos que no sean imágenes compatibles
    fi

    # Si es .webp, forzar solo compresión
    if [ "$EXT_ORIGEN" = "webp" ]; then
        MODO_ACTUAL="--compress"
    fi

    # Definición de Destino si no se pasó explícitamente
    if [ -z "$ARCH_DESTINO" ]; then
        local DIR_ORIGEN
        DIR_ORIGEN="$(dirname "$ARCH_ORIGEN")"
        
        if [ "$MODO_ACTUAL" = "--webp" ]; then
            local NOMBRE_BASE
            NOMBRE_BASE="$(basename "$ARCH_ORIGEN" ."$EXT_ORIGEN")"
            ARCH_DESTINO="${DIR_ORIGEN}/${NOMBRE_BASE}.webp"
        else
            ARCH_DESTINO="$(mktemp "${DIR_ORIGEN}/temp_img_XXXXXX.${EXT_ORIGEN}")"
            USANDO_TEMPORAL=1
        fi
    fi

    # Comando de ImageMagick según versión
    local CMD_MAGICK="magick"
    if ! command -v magick &> /dev/null; then
        CMD_MAGICK="convert"
    fi

    echo "-> Procesando: '$ARCH_ORIGEN'"

    if [ "$MODO_ACTUAL" = "--webp" ]; then
        cwebp -q 80 "$ARCH_ORIGEN" -o "$ARCH_DESTINO" &> /dev/null
    else
        case "$EXT_ORIGEN" in
            jpg|jpeg)
                $CMD_MAGICK "$ARCH_ORIGEN" -quality 82 "$ARCH_DESTINO"
                ;;
            png)
                pngquant --quality=65-80 --force --output "$ARCH_DESTINO" "$ARCH_ORIGEN" &> /dev/null
                if [ $? -ne 0 ]; then
                    $CMD_MAGICK "$ARCH_ORIGEN" -strip -quality 92 "$ARCH_DESTINO"
                fi
                ;;
            webp)
                cwebp -q 75 "$ARCH_ORIGEN" -o "$ARCH_DESTINO" &> /dev/null
                ;;
        esac
    fi

    if [ $? -eq 0 ]; then
        if [ $USANDO_TEMPORAL -eq 1 ]; then
            mv "$ARCH_DESTINO" "$ARCH_ORIGEN"
        fi
    else
        echo "   Error al procesar '$ARCH_ORIGEN'"
        [ $USANDO_TEMPORAL -eq 1 ] && [ -f "$ARCH_DESTINO" ] && rm -f "$ARCH_DESTINO"
    fi
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
# Lectura Inteligente de Parámetros
# ------------------------------------------------------------------------------
if [ "$1" = "--compress" ] || [ "$1" = "--webp" ]; then
    MODO="$1"
    ORIGEN="$2"
    DESTINO="$3"
else
    MODO="--compress"
    ORIGEN="$1"
    DESTINO="$2"
fi

if [ -z "$ORIGEN" ]; then
    echo "Error: Debe especificar un archivo o directorio de origen."
    mostrar_ayuda
    exit 1
fi

if [ ! -e "$ORIGEN" ]; then
    echo "Error: El archivo o directorio '$ORIGEN' no existe."
    exit 1
fi

instalar_dependencias

# ------------------------------------------------------------------------------
# Ejecución del Procesamiento (Directorio vs Archivo Único)
# ------------------------------------------------------------------------------
if [ -d "$ORIGEN" ]; then
    echo "Procesando imágenes en el directorio: '$ORIGEN'..."
    echo ""
    
    # Habilitar nullglob para evitar errores si no hay archivos con alguna extensión
    shopt -s nullglob
    ARCHIVOS=("$ORIGEN"/*.jpg "$ORIGEN"/*.jpeg "$ORIGEN"/*.png "$ORIGEN"/*.webp "$ORIGEN"/*.JPG "$ORIGEN"/*.JPEG "$ORIGEN"/*.PNG "$ORIGEN"/*.WEBP)
    shopt -u nullglob

    if [ ${#ARCHIVOS[@]} -eq 0 ]; then
        echo "No se encontraron imágenes compatibles (.jpg, .png, .webp) en '$ORIGEN'."
        exit 0
    fi

    for ARCHIVO in "${ARCHIVOS[@]}"; do
        # Evitar procesar archivos si son subdirectorios
        if [ -f "$ARCHIVO" ]; then
            procesar_archivo "$ARCHIVO" "" "$MODO"
        fi
    done

    echo ""
    echo "¡Proceso de directorio finalizado exitosamente!"
else
    # Si existe destino y ya existe el archivo, solicitar confirmación
    if [ -n "$DESTINO" ] && [ -f "$DESTINO" ]; then
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

    procesar_archivo "$ORIGEN" "$DESTINO" "$MODO"
    echo "¡Proceso completado exitosamente!"
fi