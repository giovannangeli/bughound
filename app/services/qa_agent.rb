require "openai"

class QaAgent
  def initialize(code, language)
    @code = code
    @language = language
    @client = OpenAI::Client.new
  end

  def run
    prompt = <<~TEXT
      Tu es un agent QA expert en développement logiciel. Tu vas analyser du code écrit en #{@language}.

      Fournis un retour rigoureux, structuré et professionnel, destiné à un·e développeur·se junior.

      Structure ta réponse exactement ainsi (ne change jamais l’ordre ni les emojis) :

      📊 Score qualité globale : 8/10
      La qualité globale du code est bonne, avec quelques axes d'amélioration.

      🧾 Résumé global :
      Résume en 2-3 phrases ce que fait le code et son objectif.

      🛡️ Sécurité (score sur 10) :
      Détaille les points liés à la sécurité. Note : X/10

      ⚙️ Performance (score sur 10) :
      Commente sur la rapidité, les requêtes éventuelles, etc. Note : X/10

      📐 Lisibilité et qualité du code (score sur 10) :
      Nomme les bonnes/mauvaises pratiques de lisibilité. Note : X/10

      🧪 Recommandations de tests (score sur 10) :
      Suggère les tests à ajouter. Note : X/10

      🔧 Proposition de correction :
      Propose un code refactorisé si besoin, ou dis “Aucune correction nécessaire.”

      Voici le code à analyser :

      #{@code}
    TEXT

    response = @client.chat(
      parameters: {
        model: "gpt-4",
        messages: [
          { role: "system", content: "Tu es un expert QA en code logiciel." },
          { role: "user", content: prompt }
        ],
        temperature: 0.4
      }
    )

    response.dig("choices", 0, "message", "content")
  end
end
