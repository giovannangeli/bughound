module AnalysesHelper
  def markdown(text)
    renderer = Redcarpet::Render::HTML.new(hard_wrap: true, filter_html: true)
    options = {
      autolink: true,
      fenced_code_blocks: true,
      tables: true,
      underline: true
    }
    Redcarpet::Markdown.new(renderer, options).render(text).html_safe
  end

  def analysis_type_info(ai_provider)
    case ai_provider
    when "openai" then { name: "Analyse rapide", color: "#10b981", icon: "fa-bolt" }
    when "claude" then { name: "Analyse expert", color: "#3b82f6", icon: "fa-brain" }
    when "tests" then { name: "Tests auto", color: "#8b5cf6", icon: "fa-flask" }
    when "smells" then { name: "Code smells", color: "#f59e0b", icon: "fa-bug" }
    when "improve" then { name: "Refactoring", color: "#ec4899", icon: "fa-tools" }
    else { name: "Analyse", color: "#6b7280", icon: "fa-code" }
    end
  end

  def extract_global_score(ai_feedback, ai_provider)
    return nil if ai_feedback.blank?

    score_patterns = case ai_provider
    when "openai", "claude"
      [
        /📊.*?Score.*?(\d{1,2})\/10/mi,
        /Score.*?qualité.*?(\d{1,2})\/10/mi,
        /Score.*?global.*?(\d{1,2})\/10/mi
      ]
    when "tests"
      [
        /📊.*?Score.*?(\d{1,2})\/10/mi,
        /Score.*?(\d{1,2})\/10/mi
      ]
    when "smells"
      [
        /📊.*?Score.*?(\d{1,2})\/10/mi,
        /Score.*?(\d{1,2})\/10/mi
      ]
    when "improve"
      []
    else
      [/📊.*?Score.*?(\d{1,2})\/10/mi]
    end

    score_patterns.each do |pattern|
      match = ai_feedback.match(pattern)
      if match
        score = match[1].to_i
        return score if score.between?(1, 10)
      end
    end

    nil
  rescue => e
    Rails.logger.error "Erreur extraction score: #{e.message}"
    nil
  end

  def score_badge_info(score)
    return { text: "N/A", color: "#9ca3af", bg_color: "#f3f4f6" } if score.nil?

    case score
    when 1..4
      { text: "#{score}/10", color: "#dc2626", bg_color: "#fef2f2" }
    when 5..6
      { text: "#{score}/10", color: "#ea580c", bg_color: "#fff7ed" }
    when 7..8
      { text: "#{score}/10", color: "#059669", bg_color: "#f0fdf4" }
    when 9..10
      { text: "#{score}/10", color: "#047857", bg_color: "#ecfdf5" }
    else
      { text: "N/A", color: "#9ca3af", bg_color: "#f3f4f6" }
    end
  end

  def clean_tests_feedback(text)
    return "" if text.blank?
    t = text.dup

    t.gsub!(/^\s*📋\s*Tests\s+générés\s+automatiquement.*$/i, "")
    t.gsub!(/^\s*📊\s*Score\s*[:：].*$/i, "")
    t.gsub!(/^\s*Score\s*[:：].*$/i, "")
    t.gsub!(/\n{3,}/, "\n\n")

    t.strip
  end

  def clean_feedback_for_pdf(text, provider:)
    return "" if text.blank?
    t = text.dup

    t = clean_tests_feedback(t) if provider == "tests" && respond_to?(:clean_tests_feedback)

    %w[📊 🛡️ ⚙️ 📐 🧪 🔧 🧾 👃 ✨ 📋 🎯 💻 📚 🔴 🟡 🔍 🔢 📝 🌀 🎓 🚀].each do |emoji|
      t.gsub!(emoji, "")
    end

    t.strip
  end

  def parse_tests_feedback(text)
    return {} if text.blank?
    t = text.dup

    t.gsub!("\r\n", "\n")

    intro         = t[/^\s*(?:Le code|Le contrôleur|.*?tests?).*?(?=\n\s*🧪|$)/mi]
    recommendations = t[/🧪.*?Recommandations.*?:?\s*(.*?)(?=\n\n|$)/mi]
    framework     = t[/Framework\s*:\s*([^\n]+)/i, 1]

    scenarios_blk = t[/Scénarios\s+testés\s*:?\s*(.*?)(?=\n\s*💻|^\s*Code des tests|^\s*📚|^\s*Instructions|^\s*Notes|$\z)/mi, 1]

    code = t[/```[a-zA-Z]*\n(.*?)```/m, 1] || t[/^\s*💻.*?\n(.*)/m, 1]

    instructions = t[/(?:📚\s*)?Instructions d'exécution\s*:?\s*(.*?)(?=\n\s*Notes|$\z)/mi, 1]

    notes = t[/[ℹ️]?\s*Notes\s+importantes\s*:?\s*((?:.|\n)*)\z/mi, 1]

    {
      intro:          intro&.strip,
      recommendations: recommendations&.strip,
      framework:      framework&.strip,
      scenarios:      scenarios_blk&.strip,
      code:           code&.rstrip,
      instructions:   instructions&.strip,
      notes:          notes&.strip
    }
  end

  def extract_reco_score(line)
    return nil if line.blank?
    m = line.match(/(\d{1,2})\s*\/\s*10/)
    m ? m[1].to_i : nil
  end

  # GARDE LA VERSION ORIGINALE ROBUSTE
  def parse_ai_feedback(feedback)
    return { sections: {}, correction: nil } if feedback.blank?

    text = feedback.to_s.dup
    text.gsub!("\r\n", "\n")

    # Correction (tout ce qui suit un titre 🔧/🛠 "Proposition/Correction")
    correction_match = text.match(
      /^[^\S\r\n]*[🔧🛠]\s*(?:Proposition.*|Correction.*)\s*:?\s*\n([\s\S]*?)\z/m
    )
    correction = correction_match ? correction_match[1].strip : nil

    # Sections principales avec patterns robustes
    patterns = {
      resume: /
        [🧾📄]\s*
        (?:Résumé\sglobal|Résumé|Overview)
        \s*:?
        \s*
        (.*?)
        (?=\n[ \t]*[🛡️🔐⚙️🚀📐🧩🧪🔬📊🔧🛠]|\z)
      /mx,

      security: /
        [🛡️🔐]\s*
        (?:Sécurité|Security)
        \s*:?
        \s*
        (.*?)
        (?=\n[ \t]*[⚙️🚀📐🧩🧪🔬📊🔧🛠]|\z)
      /mx,

      performance: /
        [⚙️🚀]\s*
        (?:Performance|Performances?)
        \s*:?
        \s*
        (.*?)
        (?=\n[ \t]*[📐🧩🧪🔬📊🔧🛠]|\z)
      /mx,

      readability: /
        [📐🧩]\s*
        (?:Lisibilit[eé][^\n]*|Readability[^\n]*|Qualit[ée][^\n]*)
        \s*:?
        \s*
        (.*?)
        (?=\n[ \t]*[🧪🔬📊🔧🛠]|\z)
      /mx,

      tests: /
  [🧪🔬]\s*
  (?:Recommandations?\sde\stests|Tests|Test\srecommendations?)
  \s*:?
  \s*
  (.*?)
  (?=\n[ \t]*\*\*Points\scritiques|\n[ \t]*[📊🔧🛠]|\z)
/mx,
    }

    sections = {}
    patterns.each do |key, rx|
      if (m = text.match(rx))
        body = m[1].strip
        # Extraire le score
        raw_score = body[/\b(\d{1,2})\s*\/\s*10\b/, 1]
        score = raw_score&.to_i
        score = nil unless score&.between?(0, 10)
        body = body.sub(/\b\d{1,2}\s*\/\s*10\b\.?/, '').strip
        sections[key] = { body: body, score: score }
      end
    end

    { sections: sections, correction: correction }
  end

  # NOUVELLE MÉTHODE pour traitement spécial code smells
  def process_smells_content(body, section_key)
    # Enlever les crochets
    body = body.gsub(/^\[|\]$/, '').strip
    
    # Traitement spécial pour la section Tests
    if section_key == :tests
      # Arrêter avant les détails code smells
      body = body.split(/👃.*?Code Smells/i).first&.strip || body
      body = body.split(/🎯.*?Nombre/i).first&.strip || body
      # Garder seulement la première phrase/ligne
      body = body.split(/\n/).first&.strip || body
    end
    
    body
  end

# Méthode pour nettoyer le feedback du mode improve
def clean_improve_feedback(feedback)
  return "" if feedback.blank?
  
  text = feedback.dup

# Supprimer TOUS les emojis parasites isoles
  text.gsub!(/^🎯\s*/, '')
  text.gsub!(/^\s*🎯\s*$/, '')
  text.gsub!(/^📝\s*/, '')
  text.gsub!(/^\s*📝\s*$/, '')
  text.gsub!(/^🚀\s*/, '')
  text.gsub!(/^\s*🚀\s*$/, '')
  
  # Supprimer tous les blocs de code ```...```
  text.gsub!(/```[a-zA-Z]*\n.*?```/m, '')
  
  # Supprimer la ligne "Code refactorisé :"
  text.gsub!(/^.*Code refactorisé\s*:.*$/i, '')
  
  # Supprimer la ligne "Code amélioré automatiquement"
  text.gsub!(/^.*Code amélioré automatiquement.*$/i, '')
  
  # Nettoyer les doubles sauts de ligne
  text.gsub!(/\n{3,}/, "\n\n")
  
  text.strip
end
end
