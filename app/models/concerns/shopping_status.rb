class ShoppingStatus
  include ActiveModel::Model
  attr_accessor :price, :p_count, :max_count, :item_name, :novelty_flg, :item_purchase_status
  
  validates :price,
    presence: true,
    numericality: {allow_blank: true, only_integer: true}
  
  validates :p_count,
    presence: true,
    numericality: {allow_blank: true, only_integer: true}
  
  validates :max_count,
    presence: true,
    numericality: {allow_blank: true, only_integer: true}
  
  validates :novelty_flg,
    presence: true,
    numericality: {allow_blank: true, only_integer: true}
  
  validate :max_valid?
  
  private
    #購入数チェック
    def max_valid?
      errors.add(:p_count, 'は' + max_count.to_s + '以下にしてください') unless p_count.to_i <= max_count.to_i
    end
end