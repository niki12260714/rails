class PlanController < ApplicationController
  layout 'top'
  before_action :authenticate_user!
  before_action :authenticate_group_member, only: [:index, :new, :edit]
  before_action :set_group, only: [:index, :new, :edit, :list]
  before_action :set_pre_path, only: [:edit]
  before_action :set_priority_list, only: [:new, :edit]
  before_action :set_seach_list, only:[:index]
  include Log, Buy, Withdrawal
  
  def index
    #Buyにあるソートの共通関数を使用
    str_sort = get_sort(params[:colum], params[:sort])

    #検索条件を設定
    if params[:search].nil? or params[:search] == "0"
      str_where = "0=0"
    elsif params[:search] == "1"
      str_where = "purchases.purchase_user_id is null"
    else
      str_where = "purchases.space_number is null or purchases.space_number = ''"
    end
    
    #表示ページの設定があるか確認し、無ければデフォルト設定
    if session["pager"].nil? then @pager_set = 10 else @pager_set = session[:pager] end
    
    #hiddenフィールドに埋めるため、使用した条件を@で送っておく
    if params[:colum].nil?
      @col = "space_number"
      @sort = "asc"
    else
      @col = params[:colum]
      @sort = params[:sort]
    end
    
    if params[:search].nil?
      @search = "0"
    else
      @search = params[:search]
    end
    
    #グループログを取得
    @g_log = GroupLog.where(group_id: params[:id]).order(created_at: :desc).limit(10)
    #グループメンバーを取得
    @g_member = GroupMember.get_group_member(params[:id]).where(join_status: true)
    #グループが持つアイテム情報を取得する
    if @pager_set != "all"
      @g_item = Purchase.where(group_id: params[:id]).left_joins(:user).joins(:item).joins(:purchase_members).where(str_where).select("purchases.*, items.item_name, items.circle_name").\
              paginate(page: params[:page], per_page: @pager_set).preload(:user).preload(:item).preload(purchase_members: :user).order(str_sort).distinct
    else
      @g_item = Purchase.where(group_id: params[:id]).left_joins(:user).joins(:item).joins(:purchase_members).where(str_where).select("purchases.*, items.item_name, items.circle_name").\
              preload(:user).preload(:item).preload(purchase_members: :user).order(str_sort).distinct
    end
    #金額を算出（上からグループ計、購入担当計、購入希望計）
    g_price = PurchaseMember.where(group_id: params[:id]).joins(:purchase).joins(:item).where("items.price > 0 and purchases.item_purchase_status = ?", 0).group("purchase_members.item_id").select("MAX(items.price) * SUM(purchase_members.want_count) price")
    @all_price = 0
    if g_price.length != 0
      g_price.each do |gp|
        @all_price += gp.price.to_i
      end
    end
    g_own_price = Purchase.where(group_id: params[:id], purchase_user_id: current_user.id).joins(:item).where("items.price > 0 and purchases.item_purchase_status = ?", 0).joins(:purchase_members).group("purchase_members.item_id").select("MAX(items.price) * SUM(purchase_members.want_count) price")
    @own_price = 0
    if g_own_price.length != 0
      g_own_price.each do |go|
        @own_price += go.price.to_i
      end
    end
    g_want_price = Purchase.where(group_id: params[:id]).joins(:purchase_members).joins(:item).where("items.price > 0 and purchases.item_purchase_status = ?", 0).where("purchase_members.user_id = ?", current_user.id.to_i).group("purchase_members.item_id").select("MAX(items.price) * SUM(purchase_members.want_count) price")
    @want_price = 0
    if g_want_price.length != 0
      g_want_price.each do |gw|
        @want_price += gw.price.to_i
      end
    end
  end
  
  def search
    #表示用indexを組み立てて、リダイレクト
    r_path = plan_path + '/' + params[:group_id] + '/' + params[:colum] + '/' + params[:sort] + '/' + params[:search]
    redirect_to r_path
  end
  
  def new
    #グループメンバーを取得（購入数欄表示の為）
    get_member_data(0, params[:id])
    #空のplanモデルを作る※購入担当をログインユーザーに指定する
    @plan = Plan.new(group_id: params[:id], mode: "new", cr: @cr, ac: @ac, item_id: nil, purchase_user_id: current_user.id)
    #引き続き入力なのかを判定、判定が終わればセッションを破棄
    if session[:item_continue]
      session.delete(:item_continue)
      #サークル情報を引き継ぐ指定で来たら、値を設定する
      if session[:circle_name]
        @plan.circle_name = session[:circle_name]
        @plan.block_number = session[:block_number]
        @plan.space_number = session[:space_number]
        #サークル名、ブロック番号、配置番号のセッションを破棄
        session.delete(:circle_name)
        session.delete(:block_number)
        session.delete(:space_number)
      end
    else
      #引継ぎ情報がない新規作成は、前画面のURLをセッションに保持する
      set_pre_path
    end
    #キャンセルボタン押下時の戻り先のパスを指定
    if @cr == "plan" then @rtn_path = plan_path + '/' + params[:id] else @rtn_path = shopping_group_path + '/' + params[:id] end
  end
  
  def edit
    #グループメンバーを取得（購入数欄表示の為）
    get_member_data(params[:item_id], params[:id])
    #itemsとpurchasesを取得する
    item = Item.find_by(id: params[:item_id])
    purchase = Purchase.find_by(item_id: params[:item_id], group_id: params[:id])
    #planモデルに値を詰める
    @plan = Plan.new(group_id: params[:id], mode: "edit", cr: @cr, ac: @ac, item_id: item.id, item_name: item.item_name, circle_name: item.circle_name, \
            space_number: purchase.space_number, block_number: purchase.block_number, price: item.price, novelty_flg: item.novelty_flg, \
            item_label: item.item_label, item_url: item.item_url, item_memo: item.item_memo, purchase_user_id: purchase.purchase_user_id, priority: purchase.priority)
    #キャンセルボタン押下時の戻り先のパスを指定
    if @cr == "plan" then @rtn_path = plan_path + '/' + params[:id] else @rtn_path = shopping_group_path end
  end
  
  def display
    #購入情報取得
    @purchase = Purchase.includes(:user).includes(:item).includes(purchase_members: :user).find_by(id: params[:p_id])
  end
  
  def save_data
    #Active Modelに一旦詰めてエラーチェック
    chk_model = Plan.new(item_name: params[:plan][:item_name], circle_name: params[:plan][:circle_name], space_number: params[:plan][:space_number], price: params[:plan][:price], item_memo: params[:plan][:item_memo], block_number: params[:plan][:block_number])
    if !chk_model.valid?
      @errors = chk_model.errors
      return
    end
    
    #購入数配列をエラーチェック
    rtn = chk_count(params[:want_count], params[:want_id], params[:plan][:group_id])
    if rtn == 1
      @orignal_error_message = "購入数の設定でエラーが発生しました。一度画面を閉じて、リロードしてから再度登録してください。"
      return
    elsif rtn == 2 and params[:plan][:mode] == "new"
      #新規作成時は、アイテム作成を行わない
      flash[:danger] = "購入数が全て0で設定されたため、アイテムを作成しませんでした。"
      redirect_to session[:request_from]
      return
    elsif rtn == 2 and params[:plan][:mode] == "edit"
      #更新時時は、購入情報を削除する(purchase,purchase_membersはitemsが削除される時に一緒に削除される※model定義)
      Item.find_by(id: params[:plan][:item_id]).destroy
      #ログ生成
      gl = GroupLog.new(group_id: params[:plan][:group_id], log: delete_item_log(params[:plan][:item_name], current_user.nickname))
      if gl.save
        flash[:danger] = "購入数が全て0で設定されたため、アイテムを削除しました。"
      else
        flash[:danger] = gl.errors
      end
      redirect_to session[:request_from]
      return
    end
    
     #エラーチェックに問題が無ければ、データ登録
    Item.transaction do
      #ノベルティが選択されていなければ、強制的に不明(0)に変換
      if params[:plan][:novelty_flg].nil? then n_flg = 0 else n_flg = params[:plan][:novelty_flg] end
      #ラベルに選択が無ければ、無しとする
      if params[:plan][:item_label].nil? then p_item_label = "none" else p_item_label = params[:plan][:item_label] end
      
      #ブロック番号の調整。全角A-zを半角変換
      if params[:plan][:block_number].to_s != ""
        params[:plan][:block_number] = params[:plan][:block_number].to_s.tr('ａ-ｚＡ-Ｚ','a-zA-Z')
      end
      
      #以下、新規と更新で分岐
      if params[:plan][:mode] == "new"
        #Itemモデルを作成する
        item = Item.new(item_name: params[:plan][:item_name], circle_name: params[:plan][:circle_name],\
                        price: params[:plan][:price].to_i, item_memo: params[:plan][:item_memo], \
                        item_label: p_item_label, item_url: params[:plan][:item_url], novelty_flg: n_flg)
        #Purchaseモデルをitemに紐づけて作成する
        p = item.purchases.build(group_id: params[:plan][:group_id], space_number: params[:plan][:space_number], block_number: params[:plan][:block_number], \
                               purchase_user_id: params[:plan][:purchase_user_id], priority: params[:plan][:priority])
        #一旦、itemを保存する
        item.save!
        #PurchaseMemberモデルを、購入希望のループを回しながら作成する
        params[:want_id].zip(params[:want_count]).each do |user_id, want_count|
          if want_count.to_i > 0
            pm = PurchaseMember.new(user_id: user_id, group_id: params[:plan][:group_id], item_id: item.id, purchase_id: p.id, want_count: want_count)
            pm.save!
          elsif params[:plan][:purchase_user_id] == user_id
            #購入数が入力無しや0でも、購入担当になっていればPurchaseMemberに登録
            pm = PurchaseMember.new(user_id: user_id, group_id: params[:plan][:group_id], item_id: item.id, purchase_id: p.id, want_count: 0)
            pm.save!
          end
        end
        #ログを作成する
        gl = GroupLog.new(group_id: params[:plan][:group_id], log: add_item_log(params[:plan][:item_name], current_user.nickname))
        gl.save!
        flash[:success] = "新しいアイテムを保存しました"
      else
        #Itemモデルを呼び出し、パラメーターで上書き
        item = Item.find_by(id: params[:plan][:item_id])
        item.item_name = params[:plan][:item_name]
        item.circle_name = params[:plan][:circle_name]
        item.price = params[:plan][:price].to_i
        item.item_memo = params[:plan][:item_memo]
        item.item_label = p_item_label
        item.item_url = params[:plan][:item_url]
        item.novelty_flg = n_flg
        item.save!
        #Purchaseモデルを呼び出し、パラメーターで上書き
        purchase = Purchase.find_by(item_id: params[:plan][:item_id], group_id: params[:plan][:group_id])
        purchase.space_number = params[:plan][:space_number]
        purchase.block_number = params[:plan][:block_number]
        purchase.purchase_user_id = params[:plan][:purchase_user_id]
        purchase.priority = params[:plan][:priority]
        purchase.save!
        #PurchaseMemberモデルを、購入希望のループを回しながら確認して保存or削除
        params[:want_id].zip(params[:want_count]).each do |user_id, want_count|
          if want_count.to_i > 0
            #find_or_createで更新と新規登録を自動で切り分ける
            pm = PurchaseMember.find_or_create_by(purchase_id: purchase.id, item_id: params[:plan][:item_id], group_id: params[:plan][:group_id], user_id: user_id)
            pm.want_count = want_count
            pm.save!
          elsif params[:plan][:purchase_user_id] == user_id
            #購入数が0でも、購入担当になっていればPurchaseMemberに登録
            pm = PurchaseMember.find_or_create_by(purchase_id: purchase.id, item_id: params[:plan][:item_id], group_id: params[:plan][:group_id], user_id: user_id)
            pm.want_count = 0
            pm.save!
          else
            #それ以外は削除する
            pm = PurchaseMember.find_by(purchase_id: purchase.id, item_id: params[:plan][:item_id], group_id: params[:plan][:group_id], user_id: user_id)
            pm.delete if !pm.nil?
          end
        end
        #ログを作成する
        gl = GroupLog.new(group_id: params[:plan][:group_id], log: update_item_log(params[:plan][:item_name], current_user.nickname))
        gl.save!
        flash[:success] = "アイテムの計画を変更しました"
      end
    end
    #続けて入力するかを判定、セッションにフラグを入れておく
    if params[:plan][:cotinue_flg]
      session[:item_continue] = true
      if params[:plan][:cotinue_circle_flg]
        #サークル名、ブロック番号、配置番号をセッションに保存
        session[:circle_name] = params[:plan][:circle_name]
        session[:block_number] = params[:plan][:block_number]
        session[:space_number] = params[:plan][:space_number]
      end
      redirect_to "#{plan_new_path}/#{params[:plan][:group_id]}"
    else
      redirect_to session[:request_from]
    end
    
    #以下トランザクションで失敗した時の挙動記述
    rescue => e
      flash[:danger] = e.message
      redirect_to @r_path
  end
  
  def delete
    r_path = plan_path + '/' + params[:id]
    #ログ作成のため、アイテム情報を取得する
    i_name = Item.find_by(id: params[:item_id])
    #ここでの削除は完全削除、items,purchases,purchase_members全てを削除する
    Item.find_by(id: params[:item_id]).destroy
    #ログ生成
    gl = GroupLog.new(group_id: params[:id], log: delete_item_log(i_name.item_name, current_user.nickname))
    if gl.save
      flash[:success] = "アイテムを削除しました"
    else
      flash[:danger] = gl.errors
    end
    #元の画面に戻る
    redirect_to r_path
  end
  
  def rtn_personal
    r_path = plan_path + '/' + params[:group_id]
    #ログ作成のため、アイテム情報を取得する
    i_name = Item.find_by(id: params[:item_id])
    Item.transaction do
      #個人アイテムに戻す購入希望者情報取得
      pms = PurchaseMember.where(item_id: params[:item_id], group_id: params[:group_id])
      if pms.size != 0 then
        pms.each do |pm|
          #購入希望者分の個人メモを作成する※但し購入希望数が0より大きいこと
          if pm.want_count > 0 then create_new_personal_item(pm.item_id, pm.user_id, pm.group_id) end
        end
      end
      #大元のアイテムを削除する(itemsのアソシエーションにより、purchases,purchase_membersは一緒に削除される)
      Item.find_by(id: params[:item_id]).destroy
      #ログ生成
      gl = GroupLog.new(group_id: params[:group_id], log: rtn_personal_item_log(i_name.item_name, current_user.nickname))
      gl.save!
    end
    flash[:success] = "個人メモに戻しました。"
    #元の画面に戻る
    redirect_to r_path
    rescue => e
      flash[:danger] = e.message
      redirect_to r_path
  end
  
  def match
    #一致元となる情報を取得
    @o_item = Item.find_by(id: params[:item_id])
    #一致させるアイテム一覧を取得
    @m_item = Item.joins(:purchases).merge(Purchase.where(group_id: params[:id])).where("purchases.item_purchase_status = 0").where.not(id: params[:item_id]).select("items.id as id, concat(items.item_name, '(', items.circle_name, ')') as item_name").order(:item_name)
  end
  
  def do_match
    #戻り先を設定しておく
    r_path = plan_path + '/' + params[:group_id]
    Item.transaction do
      #アイテム名をそれぞれ保存しておく
      inames = Item.where(id: params[:item_id]).or(Item.where(id: params[:m_i][:m_i])).select(:item_name)
      iname1 = inames.first.item_name
      iname2 = inames.second.item_name
      #一致させるPurchaseMemberにいて、一致元にいないPurchaseMemberを取得し、item_idを書き換える
      pms = PurchaseMember.find_by_sql(["select pa.id as id from purchase_members pa left outer join purchase_members pb on pa.group_id = pb.group_id and pa.user_id = pb.user_id and pb.item_id = ? where pa.item_id = ? and pb.user_id is null", \
          params[:item_id].to_i, params[:m_i][:m_i].to_i])
      if pms.size != 0
        #一致元のPurchaseのidを取得
        p = Purchase.find_by(item_id: params[:item_id], group_id: params[:group_id])
        PurchaseMember.where(id: pms.map{|pm| pm.id}).update_all(item_id: params[:item_id], purchase_id: p.id)
      end
      #一致させるアイテムを削除する(紐づくpurchase,purchase_membersはmodelの紐づきで削除される)
      Item.find_by(id: params[:m_i][:m_i]).destroy
      #ログ生成
      gl = GroupLog.new(group_id: params[:group_id], log: match_item_log(iname1, iname2, current_user.nickname))
      gl.save!
      
      flash[:success] = "アイテムを一致させました"
    end
    redirect_to r_path
    #以下トランザクションで失敗した時の挙動記述
    rescue => e
      flash[:danger] = e.message
      redirect_to r_path
  end
  
  def log
    #ログ出力
    @g_log = GroupLog.where(group_id: params[:id]).order(created_at: :desc)
    respond_to do |format|
      format.html
      format.csv do
        filename = 'グループログ'
        headers['Content-Disposition'] = "attachment; filename=\"#{filename}.csv\""
      end
    end
  end
  
  def list
    #全アイテム情報出力出力
    @g_item = Purchase.where(group_id: params[:id]).left_joins(:user).joins(:item).joins(:purchase_members).preload(:user).preload(:item).preload(purchase_members: :user).distinct
    respond_to do |format|
      format.html
      format.csv do
        filename = '【' + @group.group_name + '】購入一覧'
        headers['Content-Disposition'] = "attachment; filename=\"#{filename}.csv\""
      end
    end
  end
  
  def csv_upload
    #CSVアップロード
    if params[:file_up].nil?
      flash[:danger] = "登録するCSVファイルを選択してください。"
      redirect_to "#{plan_path}/#{params[:group_id]}"
      return
    end
    Item.transaction do
      CSV.foreach(params[:file_up].path, headers: true, encoding: "UTF-8") do |data|
        #Active Modelに一旦詰めてエラーチェック、エラーがあれば飛ばす
        if data[0] then iname = data[0] else iname = "新刊" end
        chk_model = Plan.new(item_name: iname, circle_name: data[1], block_number: data[2], space_number: data[3])
        next if !chk_model.valid?
        
        item = Item.new(item_name: iname, circle_name: data[1])
        p = item.purchases.build(group_id: params[:group_id], block_number: data[2], space_number: data[3], purchase_user_id: current_user.id)
        #一旦、itemを保存する
        item.save!
        pm = PurchaseMember.new(user_id: current_user.id, group_id: params[:group_id], item_id: item.id, purchase_id: p.id, want_count: 1)
        pm.save!
      end
    end
    flash[:success] = "一括登録処理を終了しました。エラーになったデータは無視されます。"
    redirect_to "#{plan_path}/#{params[:group_id]}"
    #以下トランザクションで失敗した時の挙動記述
    rescue => e
      flash[:danger] = e.message
      redirect_to "#{plan_path}/#{params[:group_id]}"
  end
  
  private
    def set_group
      #グループ情報を取得する
      @group = Group.find(params[:id])
    end
    
    def set_pre_path
      #遷移元を取得する
      path = Rails.application.routes.recognize_path(request.referer)
      # コントローラーを取得
      @cr = path[:controller]
      # アクションを取得
      @ac = path[:action]
      #セッションに遷移元を入れておく
      session[:request_from] = request.referer
    end
    
    def get_member_data(item_id, group_id)
      @group_member = GroupMember.find_by_sql(['SELECT gm.user_id, u.nickname, pm.want_count FROM (group_members gm INNER JOIN users u ON gm.user_id = u.id) LEFT OUTER JOIN purchase_members pm ON gm.user_id = pm.user_id AND gm.group_id = pm.group_id AND pm.item_id = ? WHERE gm.group_id = ? AND gm.join_status = true',\
                                            item_id, group_id])
    end
    
    def authenticate_group_member
      #ログインユーザーがグループメンバーかチェックする
      gm = GroupMember.find_by(group_id: params[:id], user_id: current_user.id)
      if gm.nil?
        flash[:danger] = "認証に問題が発生しました。グループ一覧画面をリロードし、確認してください。"
        redirect_to groups_path
      end
    end
    
    def set_priority_list
      #優先度の配列作成
      @priority_list = [["最優先", "1"], ["2番目", "2"], ["3番目", "3"]]
    end
    
    def set_seach_list
      #検索条件の配列作成
      @search_list = [["全件", "0"], ["購入担当者が決まっていない", "1"], ["スペース番号が入力されていない", "2"]]
    end
    
    def chk_count(want_array, u_array, g_id)
      #戻り値（0:正常、1:購入数の設定に異常あり、2:購入数が全て0）
      rtn = 0
      cnt_chk = 0
      #ユーザー配列のユーザー数と、GroupMemberの数が同一かチェックする
      chk = GroupMember.where(group_id: g_id, user_id: u_array)
      if chk.count != u_array.size then rtn = 1 end
      
      #購入数とユーザーidの配列を同時に回し、それぞれチェックする
      want_array.each do |want_count|
        #購入数が空白の時、0にしておく
        if want_count == "" then want_count = 0 end
        #購入数が数値であるか
        if want_count.to_s !~ /^[0-9]+$/ then rtn = 1 end
        #購入数などにミスはなく、かつ購入が1以上であるか
        if rtn == 0 and want_count.to_i > 0 then cnt_chk = 1 end
      end
      #ユーザー配列チェック、購入数字チェックが正しいが、購入数が全て0であるか
      if rtn == 0 and cnt_chk == 0 then rtn = 2 end
      rtn
    end
    
end
