# 🐞 BugHound — Analyse QA de code augmentée par IA

**BugHound** est une application web full-stack (Ruby on Rails 7) qui permet d’analyser du code source automatiquement grâce à l’intelligence artificielle.  
Pensée comme un **agent QA intelligent**, elle fournit un retour structuré, pédagogique et professionnel sur la qualité du code.

## 🚀 Fonctionnalités principales

- 📊 **Score global** et détails par catégorie : sécurité, performance, lisibilité, tests  
- 🧪 **Tests automatisés** : génération de suites prêtes à l’emploi (RSpec, Jest, Pytest, JUnit…)  
- ✨ **Refactoring automatique** : propose du code amélioré et conforme aux bonnes pratiques  
- 👃 **Détection de code smells** avec recommandations pédagogiques  
- ⚡ **Modes d’analyse multiples** : OpenAI (analyse rapide), Claude (analyse expert), tests auto, amélioration, smells  
- 📂 **Upload de fichiers ou copier-coller direct** avec détection automatique du langage  
- 📝 **Rapports PDF téléchargeables** et partage d’analyses  
- 🔒 Authentification et gestion des utilisateurs (Devise)

## 🛠️ Stack technique

- **Backend** : Ruby on Rails 7.1, PostgreSQL, Devise  
- **Frontend** : Hotwire (Turbo + Stimulus), SCSS custom, Prism.js pour le code highlight  
- **IA** : intégration **OpenAI GPT-4** et **Anthropic Claude 3.5**  
- **Autres** : WickedPDF pour l’export PDF, Dotenv pour la gestion des clés API  

## 🎯 Objectif

BugHound aide les développeurs à :  
- Obtenir un feedback clair et structuré sur leur code  
- Identifier rapidement des faiblesses de sécurité, performance ou lisibilité  
- Apprendre les bonnes pratiques en voyant un code refactorisé automatiquement  
- Gagner du temps grâce à la génération de tests unitaires  

---
