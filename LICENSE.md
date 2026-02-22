<!-- ==============================================================================

  Name:         README file
  File:         README.md
  Author:       @lorick_la_brique
  Date:         22 February 2026 - Revision 2
  Description:  Proprietary restrictive license governing the use, 
                modification, and distribution of CoreaLoader.
 
============================================================================== -->

# LICENCE RESTREINTE COREALOADER (NON-OSI)

**Version 2.0 - 22 Février 2026**

### 1. PRÉAMBULE
CoreaLoader n'est pas un logiciel "Open Source" au sens de l'OSI. Il s'agit d'une œuvre protégée par le droit d'auteur, mise à disposition pour un usage strictement privé, éducatif et expérimental. L'utilisation de ce code implique l'acceptation sans réserve des présentes conditions.

### 2. DROITS D'UTILISATION ET DE MODIFICATION
L'auteur concède à l'utilisateur une licence personnelle, non-transférable et non-exclusive pour :
* **Modifier** le code source pour des tests internes, du débogage ou un apprentissage personnel.
* **Compiler** et exécuter le binaire sur des machines physiques ou virtuelles privées.
* **Étudier** les mécanismes de transition x86_64 à des fins de recherche.

### 3. RESTRICTIONS STRICTES (INTERDICTION DE REDISTRIBUTION)
Il est formellement interdit, sous peine de poursuites civiles et pénales, de :
* **Redistribuer**, vendre, donner, sous-licencier ou louer le code source ou les binaires associés.
* **Publier** ce code sur un dépôt public (GitHub, GitLab, etc.). Tout partage ou sauvegarde en ligne doit impérativement se faire via des dépôts configurés en mode **PRIVÉ**.
* **Utiliser** des portions significatives du code pour des projets tiers destinés à la distribution publique, même sous un autre nom ou une dénomination dérivée.

### 4. ALIGNEMENT TECHNIQUE ET EXCLUSION DE GARANTIE
L'utilisateur reconnaît que la manipulation directe des registres système (CR0, CR3, CR4, EFER) et de la pagination comporte des risques de "Triple Fault" et d'instabilité matérielle. 
* Le logiciel est fourni **"TEL QUEL"**, sans aucune garantie de performance ou de stabilité.
* L'auteur ne pourra être tenu responsable d'éventuelles pertes de données ou dommages matériels.

### 5. PROPRIÉTÉ ET ATTRIBUTION
L'auteur (@lorick_la_brique) demeure l'unique détenteur des droits de propriété intellectuelle. L'en-tête de projet présent dans chaque fichier `.asm` doit être conservé en l'état dans toutes les copies privées.