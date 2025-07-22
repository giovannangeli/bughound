require "openai"

class AnalysesController < ApplicationController
  def index
    if params[:language].present?
      @analyses = Analysis.where(language: params[:language]).order(created_at: :desc)
    else
      @analyses = Analysis.all.order(created_at: :desc)
    end

    @languages = Analysis.distinct.pluck(:language).compact.sort
  end

  def new
    @analysis = Analysis.new
  end

def create
  @analysis = Analysis.new(analysis_params)

  if @analysis.save
    # Récupère le provider choisi
    ai_provider = params[:ai_provider] || "openai"

    # AJOUT DEBUG
    Rails.logger.debug "=== AI PROVIDER CHOISI ==="
    Rails.logger.debug "ai_provider: #{ai_provider}"
    Rails.logger.debug "params[:ai_provider]: #{params[:ai_provider]}"

    # Appelle la bonne API
    response = case ai_provider
when "claude"
  send_to_claude(@analysis.language, @analysis.code)
when "tests"
  generate_tests(@analysis.language, @analysis.code)
when "improve"
  improve_code(@analysis.language, @analysis.code)
else
  send_to_openai(@analysis.language, @analysis.code)
end

    @analysis.update(ai_feedback: response, ai_provider: ai_provider)
    redirect_to @analysis
  else
    render :new
  end
end

  def show
    @analysis = Analysis.find(params[:id])

    # Debug pour identifier les problèmes de parsing
    Rails.logger.debug "=== DEBUGGING SCORES ==="
    Rails.logger.debug "AI Feedback: #{@analysis.ai_feedback}"

    # Protection contre ai_feedback nil
    if @analysis.ai_feedback.blank?
      @score = nil
      @scores = {}
      Rails.logger.debug "AI Feedback est vide ou nil"
      return
    end

    # Score global - regex ultra-précise
    global_match = @analysis.ai_feedback.match(/📊.*?Score.*?(\d{1,2})\/10/mi)
    @score = global_match ? global_match[1].to_i : nil
    Rails.logger.debug "Score global détecté: #{@score}"

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

    Rails.logger.debug "Scores détectés: #{@scores}"
  end

  private

 def analysis_params
  params.require(:analysis).permit(:title, :language, :code, :uploaded_file, :ai_provider)
end

  def send_to_openai(language, code)
    client = OpenAI::Client.new(
      access_token: ENV["OPENAI_API_KEY"],
      uri_base: "https://api.openai.com/v1"
    )

    prompt = build_ultimate_prompt(language, code)

    Rails.logger.debug "=== PROMPT COMPLET ==="
    Rails.logger.debug prompt
    Rails.logger.debug "=== FIN PROMPT ==="

    Rails.logger.debug "=== DEBUG COMPLET ==="
  Rails.logger.debug "Code length: #{code.length} caractères"
  Rails.logger.debug "Prompt length: #{prompt.length} caractères"
  Rails.logger.debug "Language: #{language}"

    response = client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
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
      Tu es un expert QA senior. Analyse ce code #{language} avec rigueur professionnelle.

      BARÈMES STRICTS :
      • Sécurité : Failles critiques=1-3/10, Modérées=4-6/10, Bonnes pratiques=7-8/10, Exemplaire=9-10/10
      • Performance : Catastrophique=1-3/10, Correct=6-7/10, Optimisé=8-10/10
      • Lisibilité : Variables a,b,c=MAX 4/10, Code clair=6-7/10, Exemplaire=8-10/10
      • Tests : Non testable=1-3/10, Basique=4-6/10, Complet=8-10/10

      SPÉCIFICITÉS #{language.upcase} :
      #{get_compact_language_rules(language)}

      FORMAT OBLIGATOIRE (RESPECTER EXACTEMENT) :

      📊 Score qualité globale : X/10
      [Justification courte]

      🧾 Résumé global :
      [2-3 phrases sur l'objectif et structure]

      🛡️ Sécurité : X/10
      [Problèmes détectés + justification]

      ⚙️ Performance : X/10
      [Analyse performance + justification]

      📐 Lisibilité et qualité du code : X/10
      [Conventions, nommage + justification]

      🧪 Recommandations de tests : X/10
      [Tests manquants + justification]

      🔧 Proposition de correction :
      [Code amélioré OU "Code satisfaisant"]

      CODE :
      ```#{language.downcase}
      #{code}
      ```

      CONTRAINTES ABSOLUES :
      - TOUS les scores doivent être des NOMBRES ENTIERS (1, 2, 3... 10)
      - JAMAIS de décimales (8.75, 7.5, etc.)
      - Score global = moyenne arrondie des 4 catégories
      - Exemple : (10+7+9+9)/4 = 8.75 → Score global = 9/10
    PROMPT
  end

def send_to_claude(language, code)
  client = Anthropic::Client.new

  prompt = build_ultimate_prompt(language, code)

  Rails.logger.debug "=== CLAUDE PROMPT ==="
  Rails.logger.debug prompt
  Rails.logger.debug "=== FIN CLAUDE ==="

  response = client.messages.create(
    model: "claude-3-5-sonnet-20241022",
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
  "Erreur lors de l'appel à Claude : #{e.message}"
end

def generate_tests(language, code)
  client = Anthropic::Client.new

  prompt = build_tests_prompt(language, code)

  Rails.logger.debug "=== TESTS PROMPT ==="
  Rails.logger.debug prompt
  Rails.logger.debug "=== FIN TESTS ==="

  response = client.messages.create(
    model: "claude-3-5-sonnet-20241022",
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

  Rails.logger.debug "=== IMPROVE PROMPT ==="
  Rails.logger.debug prompt
  Rails.logger.debug "=== FIN IMPROVE ==="

  response = client.messages.create(
    model: "claude-3-5-sonnet-20241022",
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
end
