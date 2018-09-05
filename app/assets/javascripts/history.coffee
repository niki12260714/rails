# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/
$ ->
  @change_data = (target, next_target) ->
    val = $('[name=' + target + ']').val()
    if target is "date_select"
      ajax_path = '/history/get_group/' + val
    else
      ajax_path = '/history/get_member/' + val
    if val isnt ""
      $.ajax
        url: ajax_path
        dataType: "json"
        success: (results) ->
          #一旦、セレクトボックスの選択内容を全てクリアにしつつ、先頭の空カラムを送る
          $('[name=' + next_target + ']').children().remove()
          if target is "date_select"
            str = [{id:"", name:"イベントを選択"}]
          else
            str = [{id:"", name:"メンバーを選択"}]
          replaceSelectOptions(next_target, str)
          # サーバーから受け取った子カテゴリの一覧でセレクトボックスを置き換える
          replaceSelectOptions(next_target, results)
          #日付選択ならば、メンバードロップダウンを空にし、イベント選択ならばログインユーザーを選択状態にする
          if target is "date_select"
            $('[name=member_select]').children().remove()
            str = [{id:"", name:"メンバーを選択"}]
            replaceSelectOptions("member_select", str)
          else
            for result in results
              if result.ownselect is 1
                select_value = result.id
            $('[name=member_select]').val(select_value)
          return
        error: (XMLHttpRequest, textStatus, errorThrown) ->
          # 何らかのエラーが発生した場合
          #console.error("Error occurred in replaceChildrenOptions")
          #console.log("XMLHttpRequest: #{XMLHttpRequest.status}")
          #console.log("textStatus: #{textStatus}")
          #console.log("errorThrown: #{errorThrown}")
          alert '通信障害が発生しました'
          return
    return
  
  replaceSelectOptions = (target, results) ->
    #受け取った結果をセレクトボックスの末尾に追加する
    for result in results
      option = $('<option>').val(result.id).text(result.name)
      $('[name=' + target + ']').append(option)
    return