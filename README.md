<!-- ==============================================================================

  Name:         First Stage Boot Sector (MBR/VBR)
  File:         bootloader.asm
  Author:       @lorick_la_brique
  Date:         02 November 2025 - Revision 1
  Description:  16-bit code loaded at 0x7C00. Initializes segments, prints a 
                message, loads the Second Stage (starting at sector 2) into 
                memory address 0x8000, and jumps to it.
 
============================================================================== -->
# 🚀 CoreaLoader: From 16-bit BIOS to 64-bit Long Mode

CoreaLoader est un bootloader expérimental multi-étapes conçu pour faire passer un système x86 du mode réel 16 bits (BIOS) directement au mode long 64 bits (x86_64). Il agit comme un bootstrap minimal pour le noyau, gérant des étapes cruciales telles que :

- Activation de la porte A20  
- Chargement de la Global Descriptor Table (GDT)  
- Passage au mode protégé  
- Configuration de la pagination  
- Saut final vers l'exécution en 64 bits  

---

## 🧪 Compatibilité Plateforme

| Plateforme / Fonctionnalité      | Statut        | Détails                                                                 |
|----------------------------------|---------------|-------------------------------------------------------------------------|
| Architecture x86_64              | ✅ Requise     | CoreaLoader cible exclusivement les systèmes x86_64.                   |
| BIOS (Legacy Boot)              | ✅ Fonctionnel | Démarre depuis l'adresse classique 0x7C00 via BIOS.                    |
| UEFI Boot                        | ❌ Non supporté| Nécessite une implémentation distincte au format PE 64-bit.           |
| Virtualisation (QEMU)           | ✅ Testé       | Fonctionne correctement avec `qemu-system-x86_64`.                     |
| Matériel Physique               | ⚠️ Non testé   | La compatibilité réelle dépend des appels BIOS et du chipset utilisé. |
| Mode Long 64-bit                | ✅ Atteint     | Transition complète jusqu’au mode d’exécution 64-bit.                 |

## 🛠️ Build and Run

Pour exécuter CoreaLoader, vous aurez besoin de :

- QEMU (Quick Emulator)

## ⚖️ Licence CoreaLoader

Ce projet est publié sous une **Licence Restreinte**.

* ✅ **Modification :** Vous êtes autorisé à modifier le code source pour votre **usage personnel et interne** uniquement.
* ❌ **Redistribution :** Il est **strictement interdit** de redistribuer le code source original ou toute version modifiée, que ce soit sous le nom "CoreaLoader" ou tout autre nom, à des tiers.
* ©️ Le code source reste la **propriété intellectuelle exclusive** des auteurs de CoreaLoader.