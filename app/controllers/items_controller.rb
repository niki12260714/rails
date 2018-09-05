class ItemsController < ApplicationController
  layout 'item'
  before_action :authenticate_user!
  include Log

  def list
    #ソートの指定があるか確認し、無ければデフォルトを設定
    if(params[:colum].nil?)
      @col = "item_name"
      @sort = "asc"
    else
      @col = params[:colum]
      @sort = params[:sort]
    end
    
    #表示ページの設定があるか確認し、無ければデフォルト設定
    if session["pager"].nil? then @pager_set = 10 else @pager_set = session[:pager] end
    
    #グループに未設定の個人アイテムの取得
    @search_word = ""
    if !session[:search_words].nil? and session[:search_words] != ""
      @search_word = session[:search_words]
      sw = "%" + session[:search_words] + "%"
      if @pager_set != "all"
        @items = Item.get_personal_item(current_user.id).\
                where("items.item_name like ? or items.circle_name like ? or items.item_memo like ?", sw, sw, sw).\
                paginate(page: params[:page], per_page: @pager_set).order(@col + " " + @sort)
      else
        @items = Item.get_personal_item(current_user.id).\
                where("items.item_name like ? or items.circle_name like ? or items.item_memo like ?", sw, sw, sw)
      end
    else
      if @pager_set != "all"
        @items = Item.get_personal_item(current_user.id).paginate(page: params[:page], per_page: @pager_set).order(@col + " " + @sort)
      else
        @items = Item.get_personal_item(current_user.id).order(@col + " " + @sort)
      end
    end
    #検索が終わったら検索用のセッションは破棄する
    session.delete(:search_words)
    #自分が所属するグループの取得（買出し日が今日以降）、グループリストの作成
    @own_group = Group.get_group_list_future(current_user.id).order(:purchase_day).select("groups.id as id, concat(group_name, '(', DATE_FORMAT(purchase_day, '%Y/%m/%d'), ')') as group_name")
  end
  
  def new
    #空のitemモデルを作る
    @item = PersonalItem.new(mode: "new", item_id: nil, want_count: 1)
  end
  
  def edit
    #個人アイテム情報を取得する
    item = Item.find_by(id: params[:id])
    pm = PurchaseMember.find_by(item_id: params[:id], group_id: nil)
    #取得情報をitemモデルに入れる
    @item = PersonalItem.new(mode: "edit", item_id: item.id, item_name:item.item_name, circle_name: item.circle_name, price: item.price, novelty_flg: item.novelty_flg, item_memo:item.item_memo, want_count: pm.want_count)
  end
  
  def save_data
    #ノベルティに選択が無ければ、不明とする
    if params[:personal_item][:novelty_flg].nil? then n_flg = 0 else n_flg = params[:personal_item][:novelty_flg] end
    chk_model = PersonalItem.new(item_name: params[:personal_item][:item_name], circle_name: params[:personal_item][:circle_name], price: params[:personal_item][:price], item_memo: params[:personal_item][:item_memo], want_count: params[:personal_item][:want_count])
    if !chk_model.valid?
      @errors = chk_model.errors
      return
    end
    
    Item.transaction do
      #新規作成と更新で処理分岐
      if params[:personal_item][:mode] == "new"
        #入力値を元にモデルオブジェクトを生成
        item = Item.new(item_name: params[:personal_item][:item_name], circle_name: params[:personal_item][:circle_name], price: params[:personal_item][:price], item_memo: params[:personal_item][:item_memo], novelty_flg: n_flg.to_i)
        #中間テーブルの購入メンバーを生成
        item.purchase_members.build(group_id: nil,user_id: current_user.id, want_count: params[:personal_item][:want_count])
        #アイテムをDBに保存
        if item.save
          flash[:success] = "新しいアイテムを保存しました"
        else
          @errors = item.errors
          return
        end
      else
        #Itemモデルを呼び出し、パラメーターで上書き
        item = Item.find_by(id: params[:personal_item][:item_id])
        item.item_name = params[:personal_item][:item_name]
        item.circle_name = params[:personal_item][:circle_name]
        item.price = params[:personal_item][:price]
        item.item_memo = params[:personal_item][:item_memo]
        item.novelty_flg = n_flg.to_i
        #PurchaseMemberモデルを呼び出し、パラメータで上書き
        pm = PurchaseMember.find_by(item_id: params[:personal_item][:item_id], group_id: nil, user_id: current_user.id)
        pm.want_count = params[:personal_item][:want_count]
        #保存
        item.save!
        pm.save!
      end
    end
    #トランザクション終了後に個人メモ画面に戻る
    redirect_to items_list_path
    #以下トランザクションで失敗した時の挙動記述
    rescue => e
      flash[:danger] = e.message
      redirect_to items_list_path
  end
  
  def delete
    #itemsを削除する(purchasesはmodelで紐づけしているので一緒に消される)
    item = Item.find_by(id: params[:id])
    item.destroy!
    flash[:success] = "アイテムを削除しました"
    redirect_to items_path
  end
  
  def insert_group
    if params[:item].nil?
      flash[:danger] = "イベント計画に登録するアイテムを選んでください。"
      redirect_to items_path
      return
    end
    
    Item.transaction do
      #グループで値無し（個人グループ）を選択しているならば、個人のグループを作成する
      if params[:group_id][:id].empty?
        #グループとグループメンバーの親子インスタンス作成
        gc = Gpcheck.new(group_name: "新規イベント"+params[:purchase_day], purchase_day: params[:purchase_day])
        if !gc.valid?
          @errors = gc.errors
          return
        else
          group = Group.new(create_user_id: current_user.id, group_name: "新規イベント"+params[:purchase_day], purchase_day: Date.parse(params[:purchase_day]), end_flg: false)
          group.group_members.build(user_id: current_user.id, join_status: true, member_purchase_status: 0)
          group.group_logs.build(log: create_group_log(group.group_name, current_user.nickname))
          #グループをDBに保存
          group.save!
          #保存されたグループからidを取ってくる
          g_id = group.id
        end
      else
        g_id = params[:group_id][:id]
      end
      
      #中間テーブルの更新と作成
      params[:item].each do |i_id|
        purchase = Purchase.new(group_id: g_id, item_id: i_id, item_purchase_status: 0)
        purchase.save!
        purchase_member = PurchaseMember.find_by(item_id: i_id, user_id: current_user.id, group_id: nil)
        purchase_member.group_id = g_id
        purchase_member.purchase_id = purchase.id
        purchase_member.save!
        item = Item.find_by(id: i_id)
        gl = GroupLog.new(group_id: g_id, log: add_item_log(item.item_name, current_user.nickname))
        gl.save!
      end
      flash[:success] = "アイテムをイベント計画に設定しました。"
    #トランザクション終了
    end
    redirect_to items_path
    #以下トランザクションで失敗した時の挙動記述
    rescue => e
      flash[:danger] = e.message
      redirect_to items_path
  end
  
  def search
    if !params[:keywords].nil? and params[:keywords] != ""
      session[:search_words] = params[:keywords]
    else
      session.delete(:search_words)
    end
    redirect_to items_list_path
  end
  
  def event
    #グループに設定済みのアイテムの取得（ログインユーザーがpurchase_membersにあり、グループの買出し日が今日以降。グループ単位でループを回したいので、order byをかけている）
    perchase_list = PurchaseMember.joins(:group).merge(Group.get_future_group).joins(:item).where(user_id: current_user.id).preload(:group).preload(:item).preload(:purchase).order("groups.purchase_day, groups.id").preload(group: :user)
    #取得したグループ設定済みアイテムを表示用に組み立てなおす
    group_id = 0
    @group_items = Array.new()
    item_array = Array.new()
    pid_array = Array.new()
    circle_array = Array.new()
    pgi_model = PersonalGroupItem.new()
    if perchase_list.length > 0
      perchase_list.each do |purchase|
        if group_id != purchase.group_id
          #1回目のループでなければ、前のループで作っていたアイテムとid配列を独自モデルに設定し、最終形の配列に挿入し、独自モデルと配列をnewし直す
          if group_id != 0
            pgi_model.item_list = item_array
            pgi_model.purchase_id_list = pid_array
            pgi_model.circle_list = circle_array
            @group_items << pgi_model
            item_array = Array.new()
            pid_array = Array.new()
            circle_array = Array.new()
            pgi_model = PersonalGroupItem.new()
          end
          
          #現在のループで、目印group_idを更新し、独自モデルにグループ名、買出し日を設定する
          group_id = purchase.group_id
          pgi_model.group_id = purchase.group_id
          pgi_model.group_name = purchase.group.group_name
          pgi_model.purchase_day = purchase.group.purchase_day
        end
        item_array << purchase.item.item_name
        pid_array << purchase.purchase.id
        circle_array << purchase.item.circle_name
      end
      #最後のループデータを最終形の配列に挿入
      pgi_model.item_list = item_array
      pgi_model.purchase_id_list = pid_array
      pgi_model.circle_list = circle_array
      @group_items << pgi_model
    end
  end
  
  private
  
end
