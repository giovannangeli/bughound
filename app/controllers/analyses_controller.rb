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
    params.require(:analysis).permit(:title, :language, :code, :uploaded_file)
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
end
