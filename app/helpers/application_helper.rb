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
end
