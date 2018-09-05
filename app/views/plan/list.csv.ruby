require 'csv'
require 'nkf'

bom = %w(EF BB BF).map { |e| e.hex.chr }.join
csv_str = CSV.generate(bom) do |csv|
  csv_column_names = %w(優先度 本の名前 ノベルティ スペース番号 サークル名 値段 購入担当 購入希望者 購入希望数 備考)
  csv << csv_column_names
  @g_item.each do |p|
    if p.item.novelty_flg.to_i == 0 then novelty = '不明' elsif p.item.novelty_flg.to_i == 1 then novelty = '有' else novelty = '無' end
    if p.purchase_user_id.nil? or p.purchase_user_id == '' then tanto = '' else tanto = p.user.nickname end
    p.purchase_members.each do |pm|
      csv_column_values = [
        p.priority.to_s,
        p.item.item_name,
        novelty,
        p.block_number.to_s + '-' + p.space_number.to_s,
        p.item.circle_name,
        p.item.price,
        tanto,
        pm.user.nickname,
        pm.want_count,
        p.item.item_memo
      ]
      csv << csv_column_values
    end
  end
end
# 文字コード変換
# NKF::nkf('--sjis -Lw', csv_str)