module ApplicationHelper
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

  # Patterns de score selon le provider
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
    # Refactoring n'a généralement pas de score numérique
    []
  else
    [/📊.*?Score.*?(\d{1,2})\/10/mi]
  end

  # Tentative d'extraction avec chaque pattern
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

  # 1) Enlever la ligne de titre interne (on a déjà le H3 au-dessus)
  t.gsub!(/^\s*📋\s*Tests\s+générés\s+automatiquement.*$/i, "")

  # 2) Enlever toute ligne de score (on ne note pas les tests auto)
  t.gsub!(/^\s*📊\s*Score\s*[:：].*$/i, "")
  t.gsub!(/^\s*Score\s*[:：].*$/i, "")

  # 3) Nettoyage espace blanc résiduel (doubles sauts de lignes)
  t.gsub!(/\n{3,}/, "\n\n")

  t.strip
end

def clean_feedback_for_pdf(text, provider:)
  return "" if text.blank?
  t = text.dup

  # Cas spécial "tests" : on enlève le titre interne et toute ligne de score
  t = clean_tests_feedback(t) if provider == "tests" && respond_to?(:clean_tests_feedback)

  # Emojis communs qu'on ne veut pas dans le PDF
  %w[📊 🛡️ ⚙️ 📐 🧪 🔧 🧾 👃 ✨ 📋 🎯 💻 📚 🔴 🟡 🔍 🔢 📝 🌀 🎓 🚀].each do |emoji|
    t.gsub!(emoji, "")
  end

  t.strip
end

# --- Helpers dédiés à l'affichage "Tests automatiques" ---

# --- Parseur dédié au format "Tests générés automatiquement" ---
# Extrait les sections pour l’affichage "Tests auto"
  def parse_tests_feedback(text)
    return {} if text.blank?
    t = text.dup

    # Normalise
    t.gsub!("\r\n", "\n")

    # Découpe grossière par sections usuelles
    intro         = t[/^\s*(?:Le code|Le contrôleur|.*?tests?).*?(?=\n\s*🧪|$)/mi]
    recommendations = t[/🧪.*?Recommandations.*?:?\s*(.*?)(?=\n\n|$)/mi]
    framework     = t[/Framework\s*:\s*([^\n]+)/i, 1]

    # Scénarios testés : bloc après "Scénarios testés"
    scenarios_blk = t[/Scénarios\s+testés\s*:?\s*(.*?)(?=\n\s*💻|^\s*Code des tests|^\s*📚|^\s*Instructions|^\s*Notes|$\z)/mi, 1]

    # Code des tests : contenu du premier bloc ```…```
    code = t[/```[a-zA-Z]*\n(.*?)```/m, 1] || t[/^\s*💻.*?\n(.*)/m, 1]

    # Instructions d’exécution
    instructions = t[/(?:📚\s*)?Instructions d'exécution\s*:?\s*(.*?)(?=\n\s*Notes|$\z)/mi, 1]

    # Notes importantes
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

  # Extrait un score "X/10" d’une ligne
  def extract_reco_score(line)
    return nil if line.blank?
    m = line.match(/(\d{1,2})\s*\/\s*10/)
    m ? m[1].to_i : nil
  end
end