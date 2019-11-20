require 'csv'
require 'nkf'

bom = %w(EF BB BF).map { |e| e.hex.chr }.join
csv_str = CSV.generate(bom) do |csv|
  csv_column_names = %w(本の名前 サークル名 値段 冊数)
  csv << csv_column_names
  @g_item.each do |p|
    csv_column_values = [
      p.item.item_name,
      p.item.circle_name,
      p.item.price,
      p.want_count
    ]
    csv << csv_column_values
  end
end