class HistorySearch
  include ActiveModel::Model
  attr_accessor :group, :member
  
  validates :group,
    presence: true
  
  validates :member,
    presence: true
  
end