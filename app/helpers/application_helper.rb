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
end
