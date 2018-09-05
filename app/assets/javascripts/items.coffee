# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/
$ ->
  @item_change = () ->
    if $("#all_items").prop("checked")
      $('.items').prop("checked",true)
      return
    else
      $('.items').prop("checked",false)
      return