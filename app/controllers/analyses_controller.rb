require "openai"

class AnalysesController < ApplicationController
def index
  if user_signed_in?
    # Utilisateur connecté → Ses analyses avec filtres
    @analyses = current_user.analyses
    
    # Filtre par langage
    @analyses = @analyses.where(language: params[:language]) if params[:language].present?
    
    # Filtre par type d'analyse (ai_provider)
    @analyses = @analyses.where(ai_provider: params[:ai_provider]) if params[:ai_provider].present?
    
    # Ordre par date décroissante
    @analyses = @analyses.order(created_at: :desc)
  else
    # Pas connecté → Redirection vers login
    redirect_to new_user_session_path, notice: "Connectez-vous pour voir votre historique"
    return
  end
  
  # Liste des langages disponibles (inchangée)
  @languages = ["Bash", "C++", "CSS", "Go", "HTML", "Java", "JavaScript", "PHP", "Python", "Ruby", "Rust", "SQL", "TypeScript"]
end

  def new
    @analysis = Analysis.new
  end

def create
  @analysis = Analysis.new(analysis_params)

    if @analysis.save
    # Attacher l'user si connecté
    @analysis.update(user: current_user) if user_signed_in?
    # Récupère le provider choisi
    ai_provider = params[:ai_provider] || "openai"

    # Appelle la bonne API
response = case ai_provider
when "claude"
  send_to_claude(@analysis.language, @analysis.code)
when "tests"
  generate_tests(@analysis.language, @analysis.code)
when "improve"
  improve_code(@analysis.language, @analysis.code)
when "smells"
  detect_code_smells(@analysis.language, @analysis.code)
else
  send_to_openai(@analysis.language, @analysis.code)
end

    result = @analysis.update(ai_feedback: response, ai_provider: ai_provider)

    redirect_to @analysis
  else
    render :new
  end
end

  def show
    @analysis = Analysis.find(params[:id])

    # Protection contre ai_feedback nil
    if @analysis.ai_feedback.blank?
      @score = nil
      @scores = {}

      return
    end

    # Score global - regex ultra-précise
    global_match = @analysis.ai_feedback.match(/📊.*?Score.*?(\d{1,2})\/10/mi)
    @score = global_match ? global_match[1].to_i : nil


    # Scores par catégorie avec regex strictes
    @scores = {}

    # Sécurité
    security_match = @analysis.ai_feedback.match(/🛡️.*?Sécurité.*?(\d{1,2})\/10/mi)
    @scores[:security] = security_match[1].to_i if security_match

    # Performance
    performance_match = @analysis.ai_feedback.match(/⚙️.*?Performance.*?(\d{1,2})\/10/mi)
    @scores[:performance] = performance_match[1].to_i if performance_match

    # Lisibilité
    readability_match = @analysis.ai_feedback.match(/📐.*?Lisibilité.*?(\d{1,2})\/10/mi)
    @scores[:readability] = readability_match[1].to_i if readability_match

    # Tests
    testing_match = @analysis.ai_feedback.match(/🧪.*?test.*?(\d{1,2})\/10/mi)
    @scores[:testing] = testing_match[1].to_i if testing_match

    # Parse unique pour réconcilier les scores (et dispo pour la vue)
@parsed = helpers.parse_ai_feedback(@analysis.ai_feedback)

# Remplir les trous éventuels des regex avec les scores trouvés par le helper
@scores[:security]    ||= @parsed[:sections].dig(:security,    :score)
@scores[:performance] ||= @parsed[:sections].dig(:performance, :score)
@scores[:readability] ||= @parsed[:sections].dig(:readability, :score)
@scores[:testing]     ||= @parsed[:sections].dig(:tests,       :score)

# (optionnel mais conseillé) – si le score global n'a pas été trouvé par la regex,
# on le calcule à partir des sous-scores disponibles.
if @score.nil?
  vals = @scores.values.compact
  @score = (vals.sum.to_f / vals.length).round if vals.any?
end



  end

  # À ajouter dans ton AnalysesController (après la méthode show)

def share
  @analysis = find_user_analysis(params[:id])
  return unless @analysis
  
  respond_to do |format|
    format.html { redirect_to @analysis } # Pour navigation normale
    format.json { render json: { url: analysis_url(@analysis), title: @analysis.title } }
  end
end

def destroy
  @analysis = find_user_analysis(params[:id])
  analysis_title = @analysis.title.present? ? @analysis.title : "Analyse sans titre"
  
  if @analysis.destroy
    # Récupérer les filtres depuis l'URL de référence ou request
    redirect_params = {}
    if request.referer.present?
      referer_uri = URI.parse(request.referer)
      referer_params = Rack::Utils.parse_query(referer_uri.query)
      redirect_params[:language] = referer_params['language'] if referer_params['language'].present?
      redirect_params[:ai_provider] = referer_params['ai_provider'] if referer_params['ai_provider'].present?
    end
    
    redirect_to analyses_path(redirect_params), notice: "🗑️ Analyse '#{analysis_title}' supprimée avec succès"
  else
    redirect_to analyses_path, alert: "❌ Erreur lors de la suppression"
  end
end

def download_pdf
  @analysis = find_user_analysis(params[:id])
  return unless @analysis

  if @analysis.ai_feedback.present?
    # Scores (comme show), mais on neutralise le score global pour les tests auto
    global_match = @analysis.ai_feedback.match(/.*?Score.*?(\d{1,2})\/10/mi)
    @score = global_match ? global_match[1].to_i : nil

    @scores = {}
    if (m = @analysis.ai_feedback.match(/.*?Sécurité.*?(\d{1,2})\/10/mi))
      @scores[:security] = m[1].to_i
    end
    if (m = @analysis.ai_feedback.match(/.*?Performance.*?(\d{1,2})\/10/mi))
      @scores[:performance] = m[1].to_i
    end
    if (m = @analysis.ai_feedback.match(/.*?Lisibilité.*?(\d{1,2})\/10/mi))
      @scores[:readability] = m[1].to_i
    end
    if (m = @analysis.ai_feedback.match(/.*?test.*?(\d{1,2})\/10/mi))
      @scores[:testing] = m[1].to_i
    end

    # Nettoyage unifié pour le PDF (gère aussi le cas "tests")
    @clean_feedback = helpers.clean_feedback_for_pdf(
      @analysis.ai_feedback,
      provider: @analysis.ai_provider
    )

    # Pas de score global affiché pour les tests auto
    @score = nil if @analysis.ai_provider == "tests"
  end

  respond_to do |format|
    format.html { redirect_to analysis_path(@analysis) }
    format.pdf do
      render pdf: "analyse_#{@analysis.id}",
             encoding: "UTF-8",
             margin: { top: 15, left: 15, right: 15, bottom: 20 },
             footer: { center: "BugHound • Analyse ##{@analysis.id} • [page]/[topage]" }
    end
  end
end


private

# Méthode sécurisée pour trouver une analyse
def find_user_analysis(id)
  if user_signed_in?
    current_user.analyses.find(id)
  else
    redirect_to new_user_session_path, alert: "Connectez-vous pour accéder à cette fonctionnalité"
    return
  end
rescue ActiveRecord::RecordNotFound
  redirect_to analyses_path, alert: "Analyse introuvable"
  return
end

  def analysis_params
  params.require(:analysis).permit(:title, :language, :code, :uploaded_file, :ai_provider)
end

  def send_to_openai(language, code)
    client = OpenAI::Client.new(
      access_token: ENV["OPENAI_API_KEY"],
      uri_base: "https://api.openai.com/v1"
    )

    prompt = build_openai_improved_prompt(language, code)

    response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content: "Tu es un expert QA senior avec 15 ans d'expérience. Tu analyses le code avec une rigueur professionnelle MAXIMALE. Tu suis EXACTEMENT les barèmes donnés sans exception."
          },
          { role: "user", content: prompt }
        ],
        temperature: 0.1 # Ultra-bas pour cohérence maximale
      }
    )

    response.dig("choices", 0, "message", "content")
  rescue => e
    "Erreur lors de l'appel à OpenAI : #{e.message}"
  end

  def build_ultimate_prompt(language, code)
    <<~PROMPT
      Tu es un expert QA senior. Analyse ce code #{language} avec rigueur professionnelle MAXIMALE.

      RÈGLE ABSOLUE : Analyse UNIQUEMENT ce qui est PRÉSENT dans le code. Liste CHAQUE problème individuellement, PAS en catégories génériques.

      BARÈMES STRICTS :
    • Sécurité : Failles critiques=1-3/10, Modérées=4-6/10, Bonnes pratiques=7-8/10, Exemplaire=9-10/10
    • Performance : Catastrophique=1-3/10, Correct=6-7/10, Optimisé=8-10/10
    • Lisibilité : Variables a,b,c=MAX 4/10, Code clair=6-7/10, Exemplaire=8-10/10
    • Tests : Non testable=1-3/10, Basique=4-6/10, Complet=8-10/10

    SPÉCIFICITÉS #{language.upcase} :
    #{get_compact_language_rules(language)}

      FORMAT OBLIGATOIRE :

    📊 Score qualité globale : X/10
    [Justification basée sur ce qui EST dans le code]

    🧾 Résumé global :
    [2-3 phrases : type de code, objectif, structure]

    🛡️ Sécurité : X/10
    [Problèmes RÉELS détectés dans CE code]

    ⚙️ Performance : X/10
    [Problèmes RÉELS de performance dans CE code]

    📐 Lisibilité et qualité du code : X/10
    [Analyse du code PRÉSENT]

    🧪 Recommandations de tests : X/10
    [Tests manquants SPÉCIFIQUES à ce code]

    IMPORTANT : Tu DOIS obligatoirement écrire "🎯 Pistes d'amélioration :" avec l'emoji avant de commencer les points critiques.

    🎯 Pistes d'amélioration :

**Points critiques**
[Liste EXHAUSTIVE de CHAQUE bug détecté, ligne par lignel
[Si 8 bugs détectés - 8 points listés ici, si 10 bugs → 10 points]

INSTRUCTION : Chaque ligne avec un bug = 1 point distinct
Format : "**Bug précis ligne X** : Problème exact + Solution concrète"

EXEMPLES :
- **Bug TypeError ligne 23** : Addition String + Integer dans sum → Crash garanti → Convertir en Integer
- **Bug affectation ligne 15** : Utilise = au lieu de = - Modifie la variable - Remplacer par ==
- **Bug mauvaise clé ligne 26** : :retry au lieu de :retries → Retourne nil → Corriger la clé

1. **Bug précis ligne X** : Problème exact + Solution concrète
2. **Bug précis ligne Y** : Problème exact + Solution concrète [Continue jusqu'au dernier bug - NE PAS regrouper]

**Améliorations recommandées**
[Maximum 3-4 suggestions générales de bonnes pratiques]
1. **Amélioration structurelle** : Bénéfice concret
2. **Tests unitaires** : Coverage suggérée
3. **Documentation** : Clarifications nécessaires

**Temps estimé pour corrections** : [Calculer : 10min par bug simple, 15-20min par bug complexe]
      CODE :
      ```#{language.downcase}
      #{code}
      ```

      CONTRAINTES ABSOLUES :
    - Scores = NOMBRES ENTIERS uniquement (1-10)
    - COMPTER précisément le nombre de bugs ligne par ligne
    - LISTER chaque bug séparément dans Points critiques (pas de regroupement)
    - Les "Améliorations recommandées" sont DIFFÉRENTES des bugs (bonnes pratiques, tests, doc)
    - Si 10 lignes ont des bugs → 10 points critiques distincts
    - Être exhaustif : Ne jamais regrouper plusieurs bugs en 1 seul point
    PROMPT
  end

def send_to_claude(language, code)
  client = Anthropic::Client.new

  prompt = build_ultimate_prompt(language, code)

  begin


    response = client.messages.create(
      model: "claude-sonnet-4-20250514",
      max_tokens: 2000,
      messages: [
        {
          role: "user",
          content: prompt
        }
      ]
    )

    return response.content[0].text

  rescue => e

    return "Erreur lors de l'appel à Claude : #{e.message}"
  end
end

def generate_tests(language, code)
  client = Anthropic::Client.new

  prompt = build_tests_prompt(language, code)

  response = client.messages.create(
    model: "claude-sonnet-4-20250514",
    max_tokens: 2000,
    messages: [
      {
        role: "user",
          content: prompt
      }
    ]
  )

  response.content[0].text
rescue => e
  "Erreur lors de la génération de tests : #{e.message}"
end

def improve_code(language, code)
  client = Anthropic::Client.new

  prompt = build_improve_prompt(language, code)

  response = client.messages.create(
    model: "claude-sonnet-4-20250514",
    max_tokens: 2000,
    messages: [
      {
        role: "user",
        content: prompt
      }
    ]
  )

  response.content[0].text
rescue => e
  "Erreur lors de l'amélioration : #{e.message}"
end

def detect_code_smells(language, code)
  client = Anthropic::Client.new

  prompt = build_smells_prompt(language, code)

  response = client.messages.create(
    model: "claude-sonnet-4-20250514",
    max_tokens: 2000,
    messages: [
      {
        role: "user",
        content: prompt
      }
    ]
  )

  response.content[0].text
rescue => e
  "Erreur lors de la détection : #{e.message}"
end

  def get_compact_language_rules(language)
    case language.downcase.strip
    when "ruby"
      "Injection SQL, mass assignment, XSS=1-3/10. N+1 queries=3/10. Variables explicites requis. Snake_case obligatoire."
    when "python"
      "eval(), pickle, os.system=1-3/10. PEP8 obligatoire. Type hints recommandés. Docstrings requis."
    when "javascript", "js"
      "innerHTML sans validation, eval()=1-3/10. const/let vs var. Async/await recommandé."
    when "c++"
      "Buffer overflow, memory leaks=1-3/10. RAII, smart pointers requis. Const correctness."
    when "sql"
      "Injection SQL=1-3/10. INDEX manquants=3/10. SELECT * évité. Requêtes structurées."
    else
      "Standards génériques du langage. Sécurité, performance, lisibilité."
    end
  end

  def build_tests_prompt(language, code)
  test_framework = get_test_framework(language)

  <<~PROMPT
    Tu es un expert en tests automatisés. Génère des tests unitaires complets et prêts à l'emploi.

    FRAMEWORK REQUIS : #{test_framework}

    TESTS À GÉNÉRER :
    • Test de fonctionnement normal (happy path)
    • Tests des cas limites (edge cases)
    • Tests de validation des entrées
    • Tests de gestion d'erreurs
    • Tests de sécurité si pertinent

    FORMAT OBLIGATOIRE :

    📋 Tests générés automatiquement

    📊 Score : X/10
    [Évaluation de la facilité à tester ce code]

    🧪 Recommandations de tests : X/10
    [Score basé sur la complexité et le nombre de tests nécessaires]

    🧪 Framework : #{test_framework}

    🎯 Scénarios testés :
    [Liste des 4-5 scénarios couverts]

    💻 Code des tests :
    ```#{language.downcase}
    [Code complet des tests, prêt à copier-coller]
    ```

    📚 Instructions d'exécution :
    [Commandes pour lancer les tests]

    CODE À TESTER :
    ```#{language.downcase}
    #{code}
    ```

    IMPORTANT :
    - Tests 100% fonctionnels et exécutables
    - Couverture complète des cas d'usage
    - Noms de tests explicites
    - Commentaires pour chaque test
  PROMPT
end

def get_test_framework(language)
  case language.downcase.strip
  when "ruby"
    "RSpec"
  when "python"
    "pytest"
  when "javascript", "js"
    "Jest"
  when "java"
    "JUnit 5"
  when "c++"
    "Google Test"
  when "php"
    "PHPUnit"
  else
    "Framework de test standard pour #{language}"
  end
end

def build_improve_prompt(language, code)
  best_practices = get_improvement_rules(language)

  <<~PROMPT
    Tu es un expert senior en refactoring et amélioration de code. Améliore ce code selon les meilleures pratiques.

    AMÉLIORATIONS À APPLIQUER :
    #{best_practices}

    OBJECTIFS PRIORITAIRES :
    • Sécurité : Corriger toutes les failles détectées
    • Performance : Optimiser les algorithmes et structures
    • Lisibilité : Noms explicites, structure claire
    • Maintenabilité : Documentation, gestion d'erreurs
    • Best practices : Standards du langage #{language}

    FORMAT OBLIGATOIRE :

    ✨ Code amélioré automatiquement

    🎯 Améliorations apportées :
    [Liste des 4-6 améliorations principales]

    💻 Code refactorisé :
    ```#{language.downcase}
    [Code complet amélioré, prêt à utiliser]
    ```

    📝 Explications détaillées :
    [Justification de chaque amélioration majeure]

    🚀 Bénéfices obtenus :
    [Impact concret des améliorations]

    CODE ORIGINAL :
    ```#{language.downcase}
    #{code}
    ```

    CONTRAINTES :
    - Code 100% fonctionnel et compatible
    - Respect des conventions #{language}
    - Amélioration significative de la qualité
    - Documentation complète ajoutée
    - Gestion d'erreurs robuste
    - IMPORTANT : Ne pas ajouter de phrase d'introduction, commencer directement par les sections
  PROMPT
end

def get_improvement_rules(language)
  case language.downcase.strip
  when "ruby"
    "• Sécurité : Paramètres SQL, validation entrées, mass assignment\n• Performance : Éviter N+1, optimiser boucles\n• Style : Snake_case, méthodes < 30 lignes\n• Documentation : Commentaires explicites"
  when "python"
    "• Sécurité : Éviter eval(), valider entrées\n• Performance : List comprehensions, générateurs\n• Style : PEP8, type hints, docstrings\n• Documentation : Docstrings complètes"
  when "javascript", "js"
    "• Sécurité : Validation XSS, sanitization\n• Performance : Async/await, éviter DOM loops\n• Style : const/let, arrow functions\n• Documentation : JSDoc complète"
  when "java"
    "• Sécurité : Validation, exceptions\n• Performance : Streams, collections efficaces\n• Style : CamelCase, méthodes courtes\n• Documentation : Javadoc"
  else
    "• Sécurité : Validation entrées, gestion erreurs\n• Performance : Optimisation algorithmes\n• Style : Conventions du langage\n• Documentation : Commentaires explicites"
  end
end

def build_smells_prompt(language, code)
  smell_patterns = get_smell_patterns(language)

  <<~PROMPT
    Tu es un expert en détection de code smells. Analyse ce code pour identifier TOUS les problèmes de qualité sans les corriger.

    CODE SMELLS À DÉTECTER :
    #{smell_patterns}

    CRITÈRES DE DÉTECTION :
    • Long Method : >30 lignes ou >5 responsabilités
    • Magic Numbers : Nombres en dur sans constante
    • Bad Naming : Variables a,b,c ou noms non explicites
    • Duplicate Code : Blocs similaires répétés
    • Complex Conditions : >3 conditions logiques
    • God Class : Classe avec trop de responsabilités
    • Dead Code : Code non utilisé ou inaccessible

    FORMAT OBLIGATOIRE (respecter exactement cette structure) :

    📊 Score : X/10
    [Synthèse basée sur le nombre et gravité des smells]

    🛡️ Sécurité : X/10
    [Impact des smells sur la sécurité]

    ⚙️ Performance : X/10
    [Impact des smells sur la performance]

    📐 Lisibilité : X/10
    [Impact des smells sur la lisibilité]

    🧪 Tests : X/10
    [Impact des smells sur la testabilité]

    👃 Code Smells détectés

    **Synthèse**
    - 🎯 Nombre total : X smells
    - 🔝 Top 3 risques :
      1. [Intitulé court] — ligne X (Type, Xmin)
      2. [Intitulé court] — ligne X (Type, Xmin)
      3. [Intitulé court] — ligne X (Type, Xmin)

    **Critiques (🔴)**
    1. [Intitulé actionnable] — ligne X (Xmin)
    2. [Intitulé actionnable] — ligne X (Xmin)

    **Modérés (🟡)**
    1. [Intitulé actionnable] — ligne X (Xmin)
    2. [Intitulé actionnable] — ligne X (Xmin)

    **Détail par catégories**
    - 🔍 Long Methods (X) : [Liste très brève des méthodes]
    - 🔢 Magic Numbers (X) : [Exemples clés avec valeurs]
    - 📝 Bad Naming (X) : [Variables problématiques]
    - 📋 Duplicate Code (X) : [Blocs dupliqués]
    - 🌀 Complex Logic (X) : [Méthodes complexes]

    **Plan d'action**
    - Now (≤15 min) : [3-4 correctifs critiques rapides séparés par " ; "]
    - Next (≤1 h) : [Correctifs moyens]
    - Later (½-1 j) : [Refactoring plus lourd]

    **Impact pédagogique**
    - [2-3 points max sur sécurité, performance, maintenance]

    CODE À ANALYSER :
    ```#{language.downcase}
    #{code}
    ```

    CONTRAINTES ABSOLUES :
    - Localiser précisément chaque smell avec numéro de ligne
    - Donner des estimations de temps réalistes (5min, 10min, 30min, etc.)
    - Prioriser par impact business (sécurité > performance > maintenance)
    - Garder les intitulés courts et actionnables
    - Ne pas inventer de smells inexistants
    - Utiliser exactement les emojis et la structure demandée
  PROMPT
end

def get_smell_patterns(language)
  case language.downcase.strip
  when "ruby"
    "• Long Method : >30 lignes\n• Magic Numbers : Nombres sans constantes\n• Bad Naming : Variables non snake_case\n• N+1 Queries : Boucles avec requêtes"
  when "python"
    "• Long Function : >30 lignes\n• Magic Numbers : Constantes en dur\n• Bad Naming : Variables non PEP8\n• Missing Docstrings : Fonctions sans doc"
  when "javascript", "js"
    "• Long Function : >30 lignes\n• Magic Numbers : Nombres en dur\n• Var Usage : var au lieu de const/let\n• Callback Hell : Callbacks imbriqués"
  when "java"
    "• Long Method : >30 lignes\n• Magic Numbers : Constantes privées manquantes\n• God Class : Classes >500 lignes\n• Deep Nesting : Imbrications >4 niveaux"
  else
    "• Long Method : >30 lignes\n• Magic Numbers : Nombres sans explication\n• Bad Naming : Variables non explicites\n• Complex Logic : Conditions multiples"
  end
end

def build_openai_improved_prompt(language, code)
  <<~PROMPT
    Tu es un expert QA. Analyse ce code #{language} avec rigueur MAXIMALE et HONNÊTETÉ

    RÈGLE ABSOLUE D'HONNÊTETÉ :
    - Si tu n'es PAS CERTAIN qu'un problème existe → NE LE MENTIONNE PAS
    - JAMAIS inventer de failles hypothétiques
    - JAMAIS confondre les concepts entre langages (ex: "Injection SQL" en JavaScript sans DB)
    - Mieux vaut détecter 3 bugs RÉELS que 5 bugs dont 2 FAUX
    - Si tu hésites sur un terme technique → Utilise un terme générique ("Problème de sécurité" au lieu de "Injection SQL")

    RÈGLES DE SCORING :
    • Sécurité : Failles RÉELLES prouvées = 1-3/10, Aucune faille détectée = 8-10/10
    • Performance : Bugs RÉELS (division par zéro, boucles infinies) = 3-5/10, Code fonctionnel = 6-8/10
    • Lisibilité : Code illisible/incompréhensible = 3-5/10, Code clair = 7-8/10
    • Tests : Aucun test = 5/10 (neutre), Tests partiels = 6-7/10, Tests complets = 9-10/10

    SPÉCIFICITÉS #{language.upcase} :
    #{get_language_security_rules(language)}

    FORMAT OBLIGATOIRE :

    📊 Score qualité globale : X/10

    🧾 Résumé global :
    [2 phrases max - Sois factuel et honnête]

    🛡️ Sécurité : X/10
    [Liste UNIQUEMENT les failles que tu es CERTAIN d'avoir identifiées]

    ⚙️ Performance : X/10
    [Liste UNIQUEMENT les problèmes de performance RÉELS et prouvés]

    📐 Lisibilité : X/10
    [Évaluation objective du code]

    🧪 Tests : X/10
    [Si aucun test : "Aucun test présent - Score neutre"]

    🎯 Pistes d'amélioration :

    **Points critiques** (corrections immédiates)
    
    INSTRUCTION CRITIQUE : Liste UNIQUEMENT les bugs que tu es CERTAIN d'avoir trouvés.
    Format : "1. **[Type précis] (ligne X)** : Problème exact → Solution concrète"
    
    Exemples de ce qu'il FAUT faire :
    ✅ "**Mots de passe en clair (ligne 6)** : Stockage non sécurisé → Utiliser bcrypt"
    ✅ "**Division par zéro (ligne 19)** : Pas de vérification → Ajouter if ages.empty?"
    
    Exemples de ce qu'il NE FAUT PAS faire :
    ❌ "**Injection SQL** dans du code JavaScript sans base de données"
    ❌ "**Problème potentiel** sans preuve concrète"
    ❌ "**Risque de...** si tu n'es pas sûr

    SI TU DÉTECTES 0 BUG CERTAIN → Écrire "Aucun bug critique détecté avec certitude"
    SI TU DÉTECTES 3 BUGS CERTAINS → Lister 3 points (pas plus)

    **Améliorations recommandées** (bonnes pratiques)
    1. **Tests unitaires** : Ajouter tests pour méthodes critiques
    2. **Validation entrées** : Vérifier types de données
    3. **Refactoring** : Améliorer la structure si nécessaire

    ⏱️ **Temps estimé** : [Nombre de bugs × 10min]


    CODE :
    ```#{language.downcase}
    #{code}
    ```
CONTRAINTES ABSOLUES :
- HONNÊTETÉ > EXHAUSTIVITÉ
- Sois CERTAIN avant de mentionner un bug
- Utilise des termes PRÉCIS et CORRECTS pour le langage
- Ne confonds JAMAIS les concepts entre langages
- Format : "1. **[Type] (ligne X)** : Problème → Solution"
  PROMPT
end

def get_language_security_rules(language)
case language.downcase.strip
when "ruby"
"Ne mentionne 'Injection SQL' QUE si tu vois des requêtes SQL avec interpolation. Sinon dis 'Problème de sécurité'."
when "python"
"Ne mentionne 'Injection SQL' QUE si tu vois des requêtes SQL. Attention à eval(), pickle, os.system."
when "javascript", "js"
"PAS de base de données SQL par défaut. Ne dis 'Injection SQL' que si tu vois des requêtes SQL explicites. Attention à eval(), innerHTML sans validation."
when "java"
"Attention aux injections dans JDBC PreparedStatement. Validation des entrées utilisateur."
else
"Analyse les failles de sécurité RÉELLES sans faire d'hypothèses."
end
end
end