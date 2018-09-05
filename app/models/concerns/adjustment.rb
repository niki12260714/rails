class Adjustment
  include ActiveModel::Model
  include ActiveModel::Validations::Callbacks
  attr_accessor :want_count, :p_count
  
  validates :p_count,
    presence: true,
    numericality: {allow_blank: true, only_integer: true}
  
  validate :is_all_numeric?
  
  validate :match_valid?
  
  private
    #購入数数値チェック
    def is_all_numeric?
      rtn = 0
      want_count.each do |wc|
        if wc.to_s !~ /^[0-9]+$/ then rtn = 1 end
      end
      errors.add(:want_count, 'は数字で入力してください') unless rtn == 0
    end
  
    #購入数一致チェック
    def match_valid?
      if errors.empty?
        sum_count = 0
        want_count.each {|wc| sum_count += wc.to_i}
        errors.add(:want_count, 'の合計と実際の購入数を一致させてください') unless p_count.to_i == sum_count.to_i
      end
    end
end