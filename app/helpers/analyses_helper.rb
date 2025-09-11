module AnalysesHelper
  # Parse le texte renvoyé par l’IA et extrait :
  # - sections (résumé, sécurité, performance, lisibilité, tests)
  #   => { body:, score: (0..10) | nil }
  # - correction => String | nil
  #
  # Tolérant aux variations (FR/EN, ponctuation, lignes vides).
  #
  # Exemple d’entrée :
  #   🧾 Résumé global : Code globalement bon. 8/10
  #   🛡️ Sécurité : Vérifier l’input utilisateur.
  #   ⚙️ Performance : OK pour ce contexte.
  #   📐 Lisibilité : Attention au nommage des variables.
  #   🧪 Recommandations de tests : Ajouter un test pour les cas limites.
  #   🔧 Proposition de correction :
  #       Utiliser params.require(:model).permit(...)
  #
  # Exemple de retour :
  #   {
  #     sections: {
  #       resume:      { body: "Code globalement bon.", score: 8 },
  #       security:    { body: "Vérifier l’input utilisateur.", score: nil },
  #       performance: { body: "OK pour ce contexte.", score: nil },
  #       readability: { body: "Attention au nommage des variables.", score: nil },
  #       tests:       { body: "Ajouter un test pour les cas limites.", score: nil }
  #     },
  #     correction: "Utiliser params.require(:model).permit(...)"
  #   }
  #
  def parse_ai_feedback(feedback)
    return { sections: {}, correction: nil } if feedback.blank?

    text = feedback.to_s.dup
    text.gsub!("\r\n", "\n") # normalise les retours

    # --- 1) Correction (tout ce qui suit un titre 🔧/🛠 "Proposition/Correction") ---
    correction_match = text.match(
  /^[^\S\r\n]*[🔧🛠]\s*(?:Proposition.*|Correction.*)\s*:?\s*\n([\s\S]*?)\z/m
)

    correction = correction_match ? correction_match[1].strip : nil

    # --- 2) Sections principales ---
  patterns = {
  # On capture tout ce qui suit le titre (même si le score est sur la même ligne),
  # jusqu'au prochain titre (en autorisant des espaces avant l'emoji) ou la fin.
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
    (?=\n[ \t]*[📊🔧🛠]|\z)
  /mx
}


    sections = {}
    patterns.each do |key, rx|
      if (m = text.match(rx))
        body = m[1].strip
        # Si un "8/10" figure dans le texte, on l’extrait comme score et on nettoie le body
        raw_score = body[/\b(\d{1,2})\s*\/\s*10\b/, 1]
        score = raw_score&.to_i
        score = nil unless score&.between?(0, 10)
        body = body.sub(/\b\d{1,2}\s*\/\s*10\b\.?/, '').strip
        sections[key] = { body: body, score: score }
      end
    end

    { sections: sections, correction: correction }
  end
end
