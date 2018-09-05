require 'csv'
require 'nkf'

bom = %w(EF BB BF).map { |e| e.hex.chr }.join
csv_str = CSV.generate(bom) do |csv|
  csv_column_names = %w(時間 ログ)
  csv << csv_column_names
  @g_log.each do |l|
    csv_column_values = [
      l.created_at,
      l.log
    ]
    csv << csv_column_values
  end
end
# 文字コード変換
# NKF::nkf('--sjis -Lw', csv_str)