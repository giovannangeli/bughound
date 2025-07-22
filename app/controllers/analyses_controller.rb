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
      response = send_to_openai(@analysis.language, @analysis.code)
      @analysis.update(ai_feedback: response)
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
    params.require(:analysis).permit(:title, :language, :code)
  end

  def send_to_openai(language, code)
    client = OpenAI::Client.new(
      access_token: ENV["OPENAI_API_KEY"],
      uri_base: "https://api.openai.com/v1"
    )

    prompt = build_ultimate_prompt(language, code)

    response = client.chat(
      parameters: {
        model: "gpt-4",
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
    severity_matrix = get_severity_matrix(language)
    specific_rules = get_language_specific_rules(language)
    edge_cases = get_edge_cases_rules
    language_detection = get_language_detection_rules

    <<~PROMPT
      🎯 MISSION : Analyser rigoureusement ce code #{language} avec l'exigence d'un expert QA senior.

      ⚖️ BARÈME STRICT OBLIGATOIRE :
      #{severity_matrix}

      🔍 RÈGLES SPÉCIFIQUES #{language.upcase} :
      #{specific_rules}

      🚨 CAS PARTICULIERS À GÉRER :
      #{edge_cases}

      🔍 DÉTECTION AUTOMATIQUE DE LANGAGE :
      #{language_detection}

      📋 FORMAT EXACT À RESPECTER (ZÉRO VARIATION AUTORISÉE) :

      📊 Score qualité globale : X/10
      [Commentaire bref expliquant la note - SANS mentionner le calcul de moyenne]

      🧾 Résumé global :
      [EXACTEMENT 2-3 phrases décrivant l'objectif et la structure du code]

      🛡️ Sécurité : X/10
      [Applique STRICTEMENT le barème. Faille critique = MAX 3/10]
      [Liste chaque problème détecté avec gravité]

      ⚙️ Performance : X/10
      [Code basique fonctionnel = MAX 7/10. Seuls les codes optimisés = 8-10/10]
      [Analyse complexité algorithmique O() si pertinent]

      📐 Lisibilité et qualité du code : X/10
      [Variables a,b,c = MAX 5/10. Noms explicites requis pour 7+/10]
      [Vérifie conventions, commentaires, structure]

      🧪 Recommandations de tests : X/10
      [Code sans gestion d'erreur = MAX 6/10]
      [Liste les tests spécifiques manquants]

      🔧 Proposition de correction :
      [SI problèmes détectés : CODE COMPLET corrigé avec commentaires]
      [SI code parfait : "Code de qualité professionnelle, aucune correction nécessaire."]
      [INTERDICTION ABSOLUE de recopier le code original]

      CODE À ANALYSER :
      ```#{language.downcase}
      #{code}
      ```

      ⚠️ CONTRAINTES ABSOLUES :
      - VÉRIFIER que le code correspond bien au langage #{language} sélectionné
      - Si incohérence détectée : mentionner le vrai langage en début d'analyse
      - Calcul de moyenne EXACT pour score global
      - Barèmes NON NÉGOCIABLES
      - Analyse EXHAUSTIVE de chaque ligne de code
      - Zero tolérance pour les failles de sécurité
      - Correction COMPLÈTE ou mention explicite que le code est parfait
    PROMPT
  end

  def get_severity_matrix(language)
    <<~MATRIX
      SÉCURITÉ (Barème rigide) :
      • 1-2/10 : Failles critiques (injection SQL, XSS, buffer overflow, eval() dangereux)
      • 3-4/10 : Failles modérées (validation manquante, division par zéro, gestion erreurs absente)
      • 5-6/10 : Sécurité basique avec quelques faiblesses mineures
      • 7-8/10 : Bonnes pratiques de sécurité, améliorations mineures possibles
      • 9-10/10 : Sécurité exemplaire, défense en profondeur

      PERFORMANCE (Barème strict) :
      • 1-3/10 : Algorithme catastrophique (O(n³+), boucles imbriquées inutiles)
      • 4-5/10 : Performance médiocre, optimisations évidentes manquées
      • 6-7/10 : Performance correcte pour code basique/simple
      • 8-9/10 : Code optimisé, bonnes pratiques appliquées
      • 10/10 : Performance exceptionnelle, algorithme optimal

      LISIBILITÉ (Barème exigeant) :
      • 1-3/10 : Code illisible (variables a,b,c, pas de structure, conventions ignorées)
      • 4-5/10 : Lisible mais noms de variables non explicites ou structure confuse
      • 6-7/10 : Code clair, noms corrects, structure logique
      • 8-9/10 : Excellent style, commentaires utiles, conventions respectées
      • 10/10 : Code exemplaire, documentation parfaite

      TESTS (Barème réaliste) :
      • 1-3/10 : Code non testable, aucune gestion d'erreur
      • 4-5/10 : Tests basiques possibles mais gestion d'erreurs absente
      • 6-7/10 : Code testable, quelques cas d'erreur gérés
      • 8-9/10 : Bonne testabilité, gestion d'erreurs solide
      • 10/10 : Code parfaitement testable, toutes les erreurs anticipées
    MATRIX
  end

  def get_language_specific_rules(language)
    case language.downcase.strip
    when "ruby"
      <<~RUBY_RULES
        SÉCURITÉ RUBY CRITIQUE :
        • Injection SQL : "SELECT * FROM users WHERE id = #{params[:id]}" = 1/10
        • Mass assignment : User.create(params[:user]) = 2/10
        • XSS : raw(), html_safe sans validation = 2/10
        • CSRF : skip_before_action :verify_authenticity_token = 3/10

        PERFORMANCE RUBY :
        • N+1 queries : Post.all.each { |p| p.comments.count } = 3/10
        • Pas d'includes/joins quand nécessaire = 4/10
        • Méthodes >30 lignes = MAX 6/10
        • Boucles dans boucles = MAX 5/10

        LISIBILITÉ RUBY :
        • Variables a,b,c au lieu de user,email,password = MAX 4/10
        • Pas de snake_case = -2 points
        • Méthodes sans verbe explicite = MAX 6/10
        • Pas de séparation MVC = MAX 5/10
      RUBY_RULES

    when "python"
      <<~PYTHON_RULES
        SÉCURITÉ PYTHON CRITIQUE :
        • eval(input()) ou exec() avec données utilisateur = 1/10
        • pickle.load() de source non fiable = 2/10
        • os.system() avec input utilisateur = 2/10
        • SQL string concatenation = 2/10

        PERFORMANCE PYTHON :
        • Boucles O(n²) évitables avec dict/set = 3/10
        • Pas de list comprehensions quand approprié = MAX 6/10
        • Imports dans boucles = 4/10
        • Pas de __slots__ pour classes avec beaucoup d'instances = MAX 7/10

        LISIBILITÉ PYTHON :
        • Pas de PEP8 (lignes >79 chars, pas de snake_case) = MAX 5/10
        • Pas de docstrings = MAX 6/10
        • Variables a,b,c = MAX 4/10
        • Pas de type hints en 2024 = MAX 7/10
      PYTHON_RULES

    when "javascript", "js"
      <<~JS_RULES
        SÉCURITÉ JS CRITIQUE :
        • innerHTML = userInput sans validation = 1/10
        • eval() avec données utilisateur = 1/10
        • document.write() avec input = 2/10
        • Pas de CSP headers = MAX 6/10

        PERFORMANCE JS :
        • document.getElementById() dans boucles = 4/10
        • Event listeners non nettoyés = 5/10
        • Pas d'async/await pour API calls = MAX 6/10
        • DOM manipulation excessive = 4/10

        LISIBILITÉ JS :
        • var au lieu de const/let = MAX 5/10
        • Fonctions anonymes partout = MAX 6/10
        • Variables a,b,c = MAX 4/10
        • Pas de JSDoc = MAX 7/10
      JS_RULES

    when "c++"
      <<~CPP_RULES
        SÉCURITÉ C++ CRITIQUE :
        • char buffer[10]; gets(buffer) = 1/10
        • cin >> char_array sans limite = 2/10
        • new sans delete correspondant = 3/10
        • Pointeurs dangling = 3/10

        PERFORMANCE C++ :
        • Copies d'objets inutiles (pass by value) = 4/10
        • malloc/free au lieu de new/delete = 5/10
        • Pas de const correctness = MAX 6/10
        • Algorithmes STL non utilisés = MAX 6/10

        LISIBILITÉ C++ :
        • using namespace std; = MAX 6/10
        • Variables a,b,c = MAX 4/10
        • Pas de RAII = MAX 5/10
        • Pas de smart pointers en C++11+ = MAX 6/10
      CPP_RULES

    when "sql"
      <<~SQL_RULES
        SÉCURITÉ SQL CRITIQUE :
        • "SELECT * FROM users WHERE id = " + userId = 1/10
        • GRANT ALL PRIVILEGES = 2/10
        • Mots de passe en dur = 2/10
        • Pas de prepared statements = 3/10

        PERFORMANCE SQL :
        • SELECT * au lieu de colonnes spécifiques = 4/10
        • Pas d'INDEX sur colonnes WHERE/JOIN = 3/10
        • Sous-requêtes au lieu de JOINs = 5/10
        • Pas de LIMIT sur grandes tables = 4/10

        LISIBILITÉ SQL :
        • Pas de majuscules pour keywords = MAX 6/10
        • Alias non explicites (a,b,c) = MAX 5/10
        • Requêtes sur une ligne = MAX 5/10
        • Pas d'indentation = MAX 6/10
      SQL_RULES

    else
      "Applique les standards de sécurité, performance et lisibilité génériques du langage."
    end
  end

  def get_edge_cases_rules
    <<~EDGE_CASES
    CAS PARTICULIERS OBLIGATOIRES :

    📝 CODE VIDE/INVALIDE :
    • Code < 5 lignes significatives : MAX 4/10 global
    • Syntaxe incorrecte : 1/10 partout + mention explicite
    • Code commenté uniquement : "Code insuffisant pour analyse"

    🔄 CODE PARFAIT :
    • Si vraiment aucun défaut : Score global peut être 9-10/10
    • MAIS exige justification détaillée de chaque 9-10/10
    • Rare : <5% des codes sont vraiment parfaits

    📊 CALCUL MOYENNE :
    • TOUJOURS calculer (Sécurité + Performance + Lisibilité + Tests) / 4
    • Arrondir à l'entier le plus proche
    • Si faille critique sécurité (1-3/10) : Score global MAX 4/10

    🔧 CORRECTION :
    • Si score global < 7/10 : Correction OBLIGATOIRE complète
    • Si score ≥ 7/10 : Corrections mineures ou "Code satisfaisant"
    • JAMAIS de copie identique du code original
    EDGE_CASES
  end

  def get_language_detection_rules
    <<~DETECTION
    DÉTECTION INCOHÉRENCE LANGAGE/CODE :

    🚨 SIGNES D'INCOHÉRENCE :
    • Sélection "Ruby" mais code avec #include, cout, cin → C++
    • Sélection "Python" mais code avec var, function() → JavaScript
    • Sélection "JavaScript" mais code avec def, puts → Ruby/Python
    • Sélection "Java" mais code avec #include → C++

    📋 ACTION SI INCOHÉRENCE :
    • Commencer l'analyse par : "⚠️ ATTENTION : Code détecté comme [VRAI_LANGAGE] mais [LANGAGE_SÉLECTIONNÉ] sélectionné"
    • Analyser selon le VRAI langage du code
    • Adapter les critères de sécurité/performance au bon langage
    • Mentionner l'erreur dans le résumé global
    DETECTION
  end
end
