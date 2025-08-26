#!/bin/bash

# Sistema PJN - Script de Instalación Automatizada v2.0
# Instala y configura el sistema completo de automatización de expedientes

set -e  # Salir en caso de error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

# Banner de bienvenida
echo -e "${BLUE}
╔═══════════════════════════════════════════════════════════╗
║                    Sistema PJN v2.0                      ║
║          Automatización de Expedientes Judiciales        ║
║                   Instalación Automática                 ║
╚═══════════════════════════════════════════════════════════╝
${NC}"

# Verificar requisitos del sistema
log "Verificando requisitos del sistema..."

# Verificar Python
if ! command -v python3 &> /dev/null; then
    error "Python 3 no está instalado. Instale Python 3.9+ antes de continuar."
fi

PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
if python3 -c "import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)"; then
    success "Python $PYTHON_VERSION detectado"
else
    error "Se requiere Python 3.9 o superior. Versión actual: $PYTHON_VERSION"
fi

# Verificar Git
if ! command -v git &> /dev/null; then
    error "Git no está instalado. Instale Git antes de continuar."
fi
success "Git detectado"

# Verificar si estamos en WSL, Linux o macOS
OS_TYPE="unknown"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS_TYPE="linux"
    if grep -q Microsoft /proc/version; then
        OS_TYPE="wsl"
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="macos"
fi

log "Sistema operativo detectado: $OS_TYPE"

# Crear directorio del proyecto
PROJECT_DIR="${HOME}/pjn-system"
log "Instalando en: $PROJECT_DIR"

if [ -d "$PROJECT_DIR" ]; then
    warning "El directorio $PROJECT_DIR ya existe. ¿Desea continuar? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log "Instalación cancelada"
        exit 0
    fi
fi

# Clonar repositorio
log "Clonando repositorio..."
if [ ! -d "$PROJECT_DIR" ]; then
    git clone https://github.com/MCabreraSSE/pjn.git "$PROJECT_DIR"
else
    cd "$PROJECT_DIR"
    git pull origin main
fi

cd "$PROJECT_DIR"
success "Repositorio clonado/actualizado"

# Crear entorno virtual
log "Creando entorno virtual..."
python3 -m venv .venv
success "Entorno virtual creado"

# Activar entorno virtual
source .venv/bin/activate
success "Entorno virtual activado"

# Actualizar pip
log "Actualizando pip..."
pip install --upgrade pip

# Instalar dependencias Python
log "Instalando dependencias Python..."
pip install -r requirements.txt
success "Dependencias Python instaladas"

# Instalar navegadores Playwright
log "Instalando navegadores Playwright..."
playwright install chromium
success "Playwright configurado"

# Instalar dependencias del sistema según OS
install_system_deps() {
    case $OS_TYPE in
        "linux"|"wsl")
            log "Instalando dependencias del sistema (Linux/WSL)..."
            if command -v apt-get &> /dev/null; then
                sudo apt-get update
                sudo apt-get install -y \
                    tesseract-ocr tesseract-ocr-spa \
                    ghostscript poppler-utils \
                    libglib2.0-0 libnss3 libatk1.0-0
                success "Dependencias del sistema instaladas (apt)"
            elif command -v yum &> /dev/null; then
                sudo yum install -y \
                    tesseract tesseract-langpack-spa \
                    ghostscript poppler-utils
                success "Dependencias del sistema instaladas (yum)"
            else
                warning "No se pudo detectar el gestor de paquetes. Instale manualmente: tesseract, ghostscript, poppler-utils"
            fi
            ;;
        "macos")
            log "Instalando dependencias del sistema (macOS)..."
            if command -v brew &> /dev/null; then
                brew install tesseract tesseract-lang ghostscript poppler
                success "Dependencias del sistema instaladas (brew)"
            else
                warning "Homebrew no detectado. Instale manualmente las dependencias o instale Homebrew primero"
            fi
            ;;
        *)
            warning "Sistema operativo no reconocido. Instale manualmente: tesseract, ghostscript, poppler-utils"
            ;;
    esac
}

# Preguntar si instalar dependencias del sistema
echo -e "\n${YELLOW}¿Desea instalar las dependencias del sistema? (tesseract, ghostscript, etc.)${NC}"
echo "Esto requiere privilegios de administrador (sudo)"
echo "y/N: "
read -r install_deps
if [[ "$install_deps" =~ ^[Yy]$ ]]; then
    install_system_deps
else
    warning "Dependencias del sistema omitidas. Instale manualmente si es necesario."
fi

# Crear estructura de directorios
log "Creando estructura de directorios..."
mkdir -p {expedientes,logs,config,backups,data}
success "Estructura de directorios creada"

# Copiar archivo de configuración
log "Configurando archivo de variables de entorno..."
cp .env.template .env
success "Archivo .env creado desde plantilla"

# Configurar base de datos
log "Inicializando base de datos..."
if [ -f "scripts/setup_database.py" ]; then
    python scripts/setup_database.py
    success "Base de datos inicializada"
else
    warning "Script de configuración de BD no encontrado. Se creará automáticamente en el primer uso."
fi

# Configurar permisos
log "Configurando permisos..."
chmod +x install.sh
chmod 755 {expedientes,logs,config,backups}
success "Permisos configurados"

# Mostrar siguiente pasos
echo -e "\n${GREEN}🎉 ¡Instalación completada exitosamente!${NC}\n"

echo -e "${BLUE}📋 PRÓXIMOS PASOS:${NC}"
echo -e "
1. ${YELLOW}Configurar variables de entorno:${NC}
   nano .env
   # Completar: CASE_URL, ALERT_EMAIL_TO, API keys

2. ${YELLOW}Configurar sesión del portal PJN:${NC}
   source .venv/bin/activate
   python scripts/setup_session.py --interactive

3. ${YELLOW}Ejecutar primera descarga de prueba:${NC}
   python -m pjn download --case-url 'TU_URL' --test

4. ${YELLOW}Iniciar web dashboard:${NC}
   python -m pjn web --port 8080
   # Acceder en: http://localhost:8080

5. ${YELLOW}Programar ejecuciones automáticas:${NC}
   python -m pjn schedule --daily --time '09:00'
"

echo -e "${BLUE}📖 RECURSOS ÚTILES:${NC}"
echo -e "
• Documentación: ${BLUE}README.md${NC}
• Configuración: ${BLUE}.env${NC}
• Logs: ${BLUE}logs/${NC}
• Issues: ${BLUE}https://github.com/MCabreraSSE/pjn/issues${NC}
• Ejemplos: ${BLUE}examples/${NC}
"

echo -e "${BLUE}🐳 USO CON DOCKER:${NC}"
echo -e "
Alternativamente, puede usar Docker:
${YELLOW}docker-compose up -d${NC}
"

echo -e "${GREEN}¡Sistema PJN listo para usar! 🚀${NC}"

# Opcional: Abrir navegador con documentación
if command -v xdg-open &> /dev/null; then
    echo -e "\n¿Desea abrir la documentación en el navegador? (y/N): "
    read -r open_docs
    if [[ "$open_docs" =~ ^[Yy]$ ]]; then
        xdg-open "https://github.com/MCabreraSSE/pjn/blob/main/README.md"
    fi
elif command -v open &> /dev/null; then  # macOS
    echo -e "\n¿Desea abrir la documentación en el navegador? (y/N): "
    read -r open_docs
    if [[ "$open_docs" =~ ^[Yy]$ ]]; then
        open "https://github.com/MCabreraSSE/pjn/blob/main/README.md"
    fi
fi
