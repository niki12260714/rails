require 'csv'
require 'nkf'

bom = %w(EF BB BF).map { |e| e.hex.chr }.join
csv_str = CSV.generate(bom) do |csv|
  csv_column_names = %w(本の名前 サークル名 ブロック番号 配置番号)
  csv << csv_column_names
  @g_item.each do |p|
    csv_column_values = [
      p.item.item_name,
      p.item.circle_name,
      '',
      ''
    ]
    csv << csv_column_values
  end
end
