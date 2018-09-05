# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/
$ ->
  @change_pager = (path, col, sort, id, search) ->
    val = $('[name=pager]').val()
    ajax_path = '/common/change_pager/' + val
    if val isnt ""
      $.ajax
        url: ajax_path
        dataType: "json"
        success: (results) ->
          if path is 'item'
            rtn_path = '/items/list/' + col + '/' + sort
          else if path is 'plan'
            rtn_path = '/plan/' + id + '/' + col + '/' + sort + '/' + search
          else if path is 'sp_own'
            rtn_path = '/shopping/own/' + col + '/' + sort
          else
            rtn_path = '/shopping/group/' + id + '/' + search + '/' + col + '/' + sort
          window.location.href = rtn_path
          return
        error: (XMLHttpRequest, textStatus, errorThrown) ->
          # 何らかのエラーが発生した場合
          #console.error("Error occurred in replaceChildrenOptions")
          #console.log("XMLHttpRequest: #{XMLHttpRequest.status}")
          #console.log("textStatus: #{textStatus}")
          #console.log("errorThrown: #{errorThrown}")
          alert '通信障害が発生しました。'
          return
    return