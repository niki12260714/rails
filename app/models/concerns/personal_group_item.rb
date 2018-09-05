class PersonalGroupItem
  include ActiveModel::Model
  attr_accessor :group_id, :group_name, :purchase_day, :item_list, :purchase_id_list, :circle_list
end