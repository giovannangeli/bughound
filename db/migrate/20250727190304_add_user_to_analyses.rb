class AddUserToAnalyses < ActiveRecord::Migration[7.1]
  def change
    add_reference :analyses, :user, null: true, foreign_key: true
  end
end
