class Analysis < ApplicationRecord
  belongs_to :user, optional: true
  # Attribut virtuel pour le fichier uploadé
  attr_accessor :uploaded_file

  # Validations
  validates :code, presence: true, length: { minimum: 10 }
  validate :code_or_file_present

  # Callback pour traiter le fichier avant sauvegarde
  before_validation :process_uploaded_file

  private

  def code_or_file_present
    if code.blank? && uploaded_file.blank?
      errors.add(:base, "Veuillez fournir du code ou uploader un fichier")
    end
  end

  def process_uploaded_file
    return unless uploaded_file.present?

    # Vérifications de sécurité
    unless valid_file_type?
      errors.add(:uploaded_file, "Type de fichier non supporté")
      return
    end

    unless valid_file_size?
      errors.add(:uploaded_file, "Fichier trop volumineux (maximum 1MB)")
      return
    end

    # Lecture et traitement du contenu
    begin
      file_content = read_file_content

      if file_content.blank?
        errors.add(:uploaded_file, "Le fichier est vide")
        return
      end

      # Si aucun code n'a été saisi manuellement, utiliser le contenu du fichier
      if code.blank?
        self.code = file_content
      end

      # Auto-détection du langage si pas déjà défini
      auto_detect_language if language.blank?

      # Titre automatique si pas défini
      auto_generate_title if title.blank?

    rescue => e
      Rails.logger.error "Erreur lors de la lecture du fichier: #{e.message}"
      errors.add(:uploaded_file, "Impossible de lire le fichier")
    end
  end

  def valid_file_type?
    return false unless uploaded_file.respond_to?(:original_filename)

    allowed_extensions = %w[.rb .py .js .ts .cpp .c .java .php .go .rs .sql .html .css .sh .bash]
    file_extension = File.extname(uploaded_file.original_filename.to_s).downcase

    allowed_extensions.include?(file_extension)
  end

  def valid_file_size?
    return false unless uploaded_file.respond_to?(:size)
    uploaded_file.size <= 1.megabyte
  end

def read_file_content
  content = uploaded_file.read

  # Nettoyage ultra-strict pour OpenAI
  content = content.force_encoding('UTF-8')
  content = content.scrub # Supprime caractères invalides
  content = content.gsub(/\r\n/, "\n") # Normalise les retours ligne
  content = content.strip # Supprime espaces début/fin

  content
rescue
  uploaded_file.rewind
  uploaded_file.read.force_encoding('UTF-8').scrub.gsub(/\r\n/, "\n").strip
end

  def auto_detect_language
    return unless uploaded_file.respond_to?(:original_filename)

    extension = File.extname(uploaded_file.original_filename.to_s).downcase

    language_map = {
      '.rb' => 'Ruby',
      '.py' => 'Python',
      '.js' => 'JavaScript',
      '.ts' => 'TypeScript',
      '.cpp' => 'C++',
      '.c' => 'C++',
      '.java' => 'Java',
      '.php' => 'PHP',
      '.go' => 'Go',
      '.rs' => 'Rust',
      '.sql' => 'SQL',
      '.html' => 'HTML',
      '.css' => 'CSS',
      '.sh' => 'Bash',
      '.bash' => 'Bash'
    }

    detected_language = language_map[extension]
    self.language = detected_language if detected_language
  end

  def auto_generate_title
    return unless uploaded_file.respond_to?(:original_filename)

    filename = uploaded_file.original_filename.to_s
    base_name = File.basename(filename, File.extname(filename))

    # Nettoyer le nom et créer un titre
    clean_name = base_name.gsub(/[_-]/, ' ').titleize
    self.title = "Analyse de #{clean_name}"
  end
end
