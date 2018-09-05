module Withdrawal
  extend ActiveSupport::Concern
  
  #イベント計画削除
  def del_group(g_id)
    #PurchaseMemberのデータを全て個人に戻す
    #同一グループで、複数人が購入希望を出しているPurchaseMemberデータを抽出、purchase_memberごとにitemを作成しpurchase_memberを更新、元のitemは削除
    multiple_pm = PurchaseMember.find_by_sql(["select p.* from purchase_members p inner join (select item_id, count(id) as cnt from purchase_members where group_id = ? group by item_id) i on p.item_id = i.item_id and i.cnt > 1 order by p.item_id", g_id.to_i])
    if multiple_pm.size != 0
      i_id = 0
      i_id_array = Array.new()
      item = Item.new()
      multiple_pm.each do |mpm|
        if mpm.want_count.to_i != 0
          #購入希望数が0以上ならば複製
          if i_id != mpm.item_id.to_i
            i_id = mpm.item_id.to_i
            i_id_array << i_id
            item = Item.find_by(id: i_id)
          end
          create_new_personal_item(mpm.item_id, mpm.user_id, mpm.group_id)
        else
          #購入希望数が0のものは削除
          PurchaseMember.find_by(id: mpm.id).destroy!
        end
      end
      #複製元となったitems及び元のpurchase_membersを削除
      Item.where(id: i_id_array).delete_all
      PurchaseMember.where(item_id: i_id_array).delete_all
    end
    
    #残っているのは個人しか購入希望を出していないpurchase_membersなので、まとめてupdate
    PurchaseMember.where(group_id: g_id).update(group_id: nil, purchase_id: nil)
    #groupsテーブルから破棄(purchases,group_members,group_logsはアソシエーションでdestroyされる)
    Group.find_by(id: g_id).destroy!
  end
  
  #メンバー退会
  def del_member(g_id, m_id)
    #自分以外も購入希望を出しているpurchase_membersを取得し、アイテムを新たに作成して、そのIDをpurchase_membersに設定し、個人設定にする
    multiple_pm = PurchaseMember.find_by_sql(["select p.* from purchase_members p inner join (select item_id, count(id) as cnt from purchase_members where group_id = ? group by item_id) i on p.item_id = i.item_id and i.cnt > 1 and p.user_id = ? and p.want_count > 0 order by p.item_id", g_id.to_i, m_id.to_i])
    if multiple_pm.size != 0
      multiple_pm.each do |mpm|
        item = Item.find_by(id: mpm.item_id)
        nitem = Item.new(item_name: item.item_name, circle_name: item.circle_name, price: item.circle_name, item_memo: item.item_memo, novelty_flg: item.novelty_flg)
        nitem.save!
        pm = PurchaseMember.find_by(id: mpm.id)
        pm.group_id = nil
        pm.purchase_id = nil
        pm.item_id = nitem.id
        pm.save!
      end
    end
    
    #purchase_memberで、希望数が1以上のアイテムはgroup_idとpurchase_idをnilにし、個人設定に戻す※複数希望は上記で行っているので、自分単独希望を処理している
    PurchaseMember.where(group_id: g_id, user_id: m_id, want_count: 1..Float::INFINITY).update_all(group_id: nil, purchase_id: nil)
    #purchase_memberで、希望数が0（購入を希望しないが、買出し担当になっている）は削除する
    PurchaseMember.where(group_id: g_id, user_id: m_id, want_count: 0).delete_all
    #残ったPurchaseに対し、買い出し担当に設定されていたアイテムを、担当者未設定(nil)にする
    Purchase.where(group_id: g_id, purchase_user_id: m_id).update_all(purchase_user_id: nil)
    
    #グループメンバーを削除する
    GroupMember.where(group_id: g_id, user_id: m_id).delete_all
  end
  
  #新しく個人メモを作成する(元となるitem_id,作成対象のuser_id, 元のgroup_id)
  def create_new_personal_item(o_item_id, o_user_id, o_group_id)
    #元のアイテム情報と購入数情報を取得
    origin_item = Item.find_by(id: o_item_id)
    oritin_pm = PurchaseMember.find_by(item_id: o_item_id, user_id: o_user_id, group_id: o_group_id)
    #新しいitemとpurchase_membersを作成する
    new_item = Item.new(item_name: origin_item.item_name, circle_name: origin_item.circle_name, price: origin_item.circle_name, item_memo: origin_item.item_memo, novelty_flg: origin_item.novelty_flg)
    new_item.purchase_members.build(group_id: nil,user_id: o_user_id, want_count: oritin_pm.want_count)
    #アイテム保存
    new_item.save!
  end
end