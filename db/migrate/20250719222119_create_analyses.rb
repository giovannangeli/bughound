class CreateAnalyses < ActiveRecord::Migration[7.1]
  def change
    create_table :analyses do |t|
      t.string :title
      t.string :language
      t.text :code
      t.text :ai_feedback

      t.timestamps
    end
  end
end
