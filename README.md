<!-- ==============================================================================

  Name:         README file
  File:         README.md
  Author:       @lorick_la_brique
  Date:         22 February 2026 - Revision 2
  Description:  Comprehensive guide for the CoreaLoader project, covering
                architecture, memory layout, and build instructions. 
 
============================================================================== -->

# 🚀 CoreaLoader: The x86_64 Gateway

**CoreaLoader** est un chargeur d'amorçage (bootloader) multi-étapes sophistiqué conçu pour propulser un processeur de l'état **Real Mode 16 bits** vers le **Long Mode 64 bits** natif. Il élimine la complexité de l'initialisation matérielle pour permettre au noyau de démarrer directement dans l'environnement le plus performant.



## 🛠️ Architecture du Pipeline
Le loader est divisé en deux étapes critiques pour maximiser l'espace et la compatibilité :

1. **Stage 1 (MBR) :** Logé dans le premier secteur (512 octets). Il réveille le BIOS, identifie le disque de démarrage et charge le Stage 2 à l'adresse `0x8000`.
2. **Stage 2 (Transition) :** Le "cerveau" du loader. 
    - **Memory Mapping :** Interroge le BIOS (E820) pour cartographier la RAM disponible.
    - **A20 Gate :** Déverrouille l'accès à la mémoire étendue.
    - **Paging 4-Levels :** Construit les tables PML4, PDPT, PD et PT avec un alignement strict de 4 Ko.
    - **GDT 64-bit :** Définit les descripteurs de segments pour le mode Long.

## 📊 État de la Mémoire (Memory Layout)
Le respect de cet alignement est crucial pour éviter les Triple Faults.

| Adresse | Usage |
| :--- | :--- |
| **`0x7C00`** | Point d'entrée BIOS (Stage 1) |
| **`0x8000`** | Exécution du Stage 2 |
| **`0x9000`** | Stockage de la Memory Map (E820) |
| **`0x10000`**| **Root Page Table (PML4) - Alignée 4KB** |
| **`0x90000`**| Stack (Pile) 64 bits |



## 🚀 Démarrage Rapide

### Prérequis
- **NASM** (Assembler)
- **QEMU** (Émulateur x86_64)
- **GNU Make** & **dd** (Build tools)

### Build & Run
```bash
make       # Génère build/corealoader.img
make run   # Lance l'émulation avec moniteur debug