class Gpcheck
  include ActiveModel::Model
  attr_accessor :group_name, :group_memo, :purchase_day
  
  validates :group_name,
    presence: true,
    length: {maximum: 20}
  
  validates :group_memo,
    length: {maximum: 400}
  
  validates :purchase_day,
    presence: true,
    isdate: true
  
  validate :future_valid?
  
  private
    #買出し日チェック
    def future_valid?
      if !purchase_day.nil? && purchase_day != ""
        errors.add(:purchase_day, 'は今日以降を指定してください') unless purchase_day >= Date.today.in_time_zone('Tokyo')
      end
    end
end