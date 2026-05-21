# frozen_string_literal: true

class AddCategoryToBooks < ActiveRecord::Migration[8.0]
  def change
    add_column :books, :category, :string
    add_index :books, :category
  end
end
