#!/usr/bin/env python3
"""
Script para actualizar los colores antiguos (cyberpunk) a los nuevos (modernos basados en #0062ff)
en todos los archivos Dart del proyecto frontend.
"""

import os
import re

# Directorio del frontend
FRONTEND_DIR = r"c:\Users\escob\Documents\Q-AIPE\frontend\lib\screens"

# Mapeo de colores antiguos a nuevos
COLOR_MAPPINGS = {
    # Cyan/Turquoise -> Azul Primario
    "Color(0xFF00D9FF)": "AppDesign.primaryBlue",
    "Color(0xFF00C6FF)": "AppDesign.primaryBlueLight",
    
    # Azul neón viejo -> Azul nuevo
    "Color(0xFF4D6FFF)": "AppDesign.primaryBlue",
    
    # Fondos oscuros -> Usar del tema
    "Color(0xFF0F111A)": "Theme.of(context).scaffoldBackgroundColor",
    "Color(0xFF0A0E1A)": "AppDesign.backgroundDark", 
    "Color(0xFF1A1F2E)": "AppDesign.surfaceDark",
    "Color(0xFF0F1419)": "AppDesign.surfaceVariantDark",
    
    # Textos grises -> Usar del design system
   "Color(0xFFA0A8B8)": "AppDesign.textSecondaryLight",
    "Color(0xFF8A92A8)": "AppDesign.textTertiaryLight",
}

def update_colors_in_file(filepath):
    """Actualiza los colores en un archivo específico"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        changes_made = False
        
        # Aplicar cada reemplazo
        for old_color, new_color in COLOR_MAPPINGS.items():
            if old_color in content:
                content = content.replace(old_color, new_color)
                changes_made = True
                print(f"  ✓ {os.path.basename(filepath)}: {old_color} → {new_color}")
        
        # Solo escribir si hubo cambios
        if changes_made:
            # Asegurarse de que tiene el import necesario
            if "AppDesign" in content and "import '../theme/design_system.dart'" not in content:
                # Buscar último import statement
                import_pattern = r"(import\s+['\"].*?['\"];?\s*\n)"
                imports = list(re.finditer(import_pattern, content))
                if imports:
                    last_import = imports[-1]
                    insert_pos = last_import.end()
                    content = (content[:insert_pos] + 
                              "import '../theme/design_system.dart'; // <--- NUEVO: Sistema de diseño\n" +
                              content[insert_pos:])
                    print(f"  ✓ Added design_system import to {os.path.basename(filepath)}")
            
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        
        return False
        
    except Exception as e:
        print(f"  ✗ Error procesando {filepath}: {e}")
        return False

def main():
    print("Actualizando colores del esquema de diseno...")
    print("Directorio: " + FRONTEND_DIR + "\n")
    
    updated_files = []
    
    # Procesar todos los archivos .dart en el directorio
    for filename in os.listdir(FRONTEND_DIR):
        if filename.endswith(".dart"):
            filepath = os.path.join(FRONTEND_DIR, filename)
            if update_colors_in_file(filepath):
                updated_files.append(filename)
    
    print("\nActualizacion completa!")
    print("Archivos modificados: " + str(len(updated_files)))
    if updated_files:
        for f in updated_files:
            print("   - " + f)

if __name__ == "__main__":
    main()
