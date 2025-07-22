class Analysis < ApplicationRecord
  validates :code, presence: true, length: { minimum: 10 }
end
