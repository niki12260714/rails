module Buy
  extend ActiveSupport::Concern
  
  #引数のユーザーが、本日の買出しで、購入担当になっているアイテムを取得する
  def own_shopping_item(uid, page, colum, sort)
    #ページャーのデフォルト設定
    set_pager_default(colum, sort)
    
    #ソート文言組み立て
    str_sort = get_sort(colum, sort)
    
    if @pager_set != "all"
      @item = Purchase.get_own_charge(uid).joins(:group).merge(Group.get_today_group).joins(:item).joins(:purchase_members).select("purchases.*, items.item_name, items.circle_name").\
              paginate(page: page, per_page: @pager_set).preload(:item).preload(:purchase_members).order(str_sort).distinct
    else
      @item = Purchase.get_own_charge(uid).joins(:group).merge(Group.get_today_group).joins(:item).joins(:purchase_members).select("purchases.*, items.item_name, items.circle_name").\
              preload(:item).preload(:purchase_members).order(str_sort).distinct
    end
  end
  
  #購入ステータスの配列を戻す
  def get_p_status
    @p_status = [["未購入", "0"],["購入済み", "1"], ["購入不可", "2"], ["一部購入", "3"], ["全て", "4"]]
  end
  
  #購入ステータスによる検索結果を取得
  def get_by_purchase_status(gid, pstatus, member, page, colum, sort)
    #ページャーのデフォルト設定
    set_pager_default(colum, sort)
    
    #where句組み立て
    str_where = "purchases.group_id = " + gid.to_s
    if pstatus.to_i != 4 then str_where += " and purchases.item_purchase_status = " + pstatus.to_s end
    if member.to_s != "all" then str_where += " and purchases.purchase_user_id = " + member.to_s end
    
    #sort句組み立て
    str_sort = get_sort(colum, sort)
    
    #検索実行
    if @pager_set != "all"
      @item = Purchase.where(str_where).joins(:item).left_joins(:user).select("purchases.*, items.item_name, items.circle_name").\
              paginate(page: page, per_page: @pager_set).preload(:item).preload(:user).order(str_sort).distinct
    else
      @item = Purchase.where(str_where).joins(:item).left_joins(:user).select("purchases.*, items.item_name, items.circle_name").\
              preload(:item).preload(:user).order(str_sort).distinct
    end
  end
  
  #引数のグループの未購入一覧を取得
  def get_not_buy_items(gid)
    @non_purchase = Purchase.joins(:item).joins(purchase_members: :user).where(group_id: gid, item_purchase_status: 0).preload(:item).preload(purchase_members: :user).uniq
  end
  
  #引数のグループの一部購入の一覧を取得
  def get_part_items(gid)
    @purchase = Purchase.includes(:item).includes(purchase_members: :user).where(group_id: gid, item_purchase_status: 3)
  end
  
  #引数のグループ、ユーザーの最終集計を取得
  #第三引数が0(未購入)なら、全部購入できたものとして精算表示、1（完全購入）ならば実績を表示
  def get_result_items(gid, uid, chk_status)
    #一部購入が無ければ集計データ取得
    #渡す本
    present_item = Purchase.includes(:item).includes(purchase_members: :user).where(group_id: gid, purchase_user_id: uid).distinct
    #受け取る本
    get_item = PurchaseMember.joins(purchase: :item).where("purchase_members.user_id = ? and purchases.group_id = ?", uid, gid).preload(:purchase).preload(:item).distinct
    #グループメンバー
    group_members = GroupMember.get_group_member(gid).where(join_status: true)
    #分析対象となるユーザー情報
    @targe_user = User.find_by(id: uid)
    
    #表示用に組み立て直す
    @other_user_list = Array.new()
    group_members.each do |gm|
      pass_item_array = Array.new()
      pass_bad_item_array = Array.new()
      pass_item_price = 0
      receive_item_array = Array.new()
      receive_bad_item_array = Array.new()
      receive_item_price = 0
      
      #渡す本を組み立てる
      present_item.each do |pitem|
        pitem.purchase_members.each do |pm|
          if pm.user_id == gm.user_id
            #ゴミデータで、purchasesがあってitemsがないデータがあったので、その対策のため、nil?を入れて確認している。以下、受け取る本も同様
            if !pitem.item.nil?
              hi = HistoryItem.new(item_name: pitem.item.item_name, count: pm.want_count, price: pitem.item.price, novelty_flg: pitem.item.novelty_flg)
              if pm.want_count > 0 && pm.purchase.item_purchase_status.to_i == chk_status.to_i
                pass_item_price = pass_item_price + (pm.want_count.to_i * pitem.item.price.to_i)
                pass_item_array << hi
              elsif pm.want_count > 0 && pm.purchase.item_purchase_status.to_i != chk_status.to_i
                #購入希望出していたけど、ステータスが購入不可のものは買えなかったもの
                pass_bad_item_array << hi
              elsif pitem.purchase_user_id != pm.user_id
                #買い出し担当以外で0件ならば買えなかったもの（逆に言えば、買出し担当で0件は別に欲しくない）
                pass_bad_item_array << hi
              end
            end
          end
        end
      end
      
      #受け取る本を組み立てる
      get_item.each do |gitem|
        if gitem.purchase.purchase_user_id == gm.user_id
          if !gitem.item.nil?
            hi = HistoryItem.new(item_name: gitem.item.item_name, count: gitem.want_count, price: gitem.item.price, novelty_flg: gitem.item.novelty_flg)
            if gitem.want_count > 0 && gitem.purchase.item_purchase_status == chk_status.to_i
              receive_item_price = receive_item_price + (gitem.want_count.to_i * gitem.item.price.to_i)
              receive_item_array << hi
            elsif gitem.want_count > 0 && gitem.purchase.item_purchase_status != chk_status.to_i
              receive_bad_item_array << hi
            else
              receive_bad_item_array << hi
            end
          end
        end
      end
      
      #整形して配列に突っ込む
      hl = HistoryList.new(pass_item: pass_item_array, pass_bad_item: pass_bad_item_array, receive_item: receive_item_array, receive_bad_item: receive_bad_item_array,\
            target_user: gm.user.nickname, pass_item_price: pass_item_price, receive_item_price: receive_item_price)
      if gm.user_id.to_i != uid.to_i
        @other_user_list << hl
      else
        @own_list = hl
      end
    end
  end
  
  def get_sort(colum, sort)
    str_space_order_asc = "CASE WHEN purchases.block_number REGEXP '[A-Z]' THEN 0  WHEN purchases.block_number REGEXP '[a-z]' THEN 1 WHEN purchases.block_number REGEXP '[ぁ-ゞ]' THEN 2 WHEN purchases.block_number REGEXP '[ア-ン]' THEN 3 ELSE 99 END, purchases.block_number, purchases.space_number"
    str_space_order_desc = "CASE WHEN purchases.block_number REGEXP '[A-Z]' THEN 4  WHEN purchases.block_number REGEXP '[a-z]' THEN 3 WHEN purchases.block_number REGEXP '[ぁ-ゞ]' THEN 2 WHEN purchases.block_number REGEXP '[ア-ン]' THEN 1 ELSE 0 END, purchases.block_number, purchases.space_number"
    #ソートの指定があるか確認し、無ければデフォルトを設定
    if colum.nil?
      str_sort = str_space_order_asc + " ASC"
    elsif  colum == "space_number" and sort == "asc"
      str_sort = str_space_order_asc + " " + sort
    elsif  colum == "space_number" and sort== "desc"
      str_sort = str_space_order_desc + " " + sort
    elsif colum == "priority"
      str_sort = "purchases.priority is null, purchases.priority " + sort
    elsif colum == "circle_name"
      str_sort = "items.circle_name = '', items.circle_name " + sort
    elsif colum == "item_name"
      str_sort = "items."+ colum + " " + sort
    end
  end
  
  private
  def set_pager_default(colum, sort)
    #表示ページの設定があるか確認し、無ければデフォルト設定
    if session["pager"].nil? then @pager_set = 10 else @pager_set = session[:pager] end
      
    #ページャーのJavaScript用に@を埋め込む
    if colum.nil?
      @col = "space_number"
      @sort = "asc"
    else
      @col = colum
      @sort = sort
    end
  end
  
end