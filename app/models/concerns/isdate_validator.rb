class IsdateValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    if chk(value)
      record.errors.add(attribute, 'は正しい日付ではありません。')
    end
  end
  
  private
    def chk(val)
      ! Date.parse(val) rescue false
    end
end