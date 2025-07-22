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
end
