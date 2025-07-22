class AddAiProviderToAnalyses < ActiveRecord::Migration[7.1]
  def change
    add_column :analyses, :ai_provider, :string
  end
end
