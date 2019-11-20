# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/
$ ->
  @change_block = () ->
    val = $('#block_number_block_number').val()
    $('#block_no').val(val)
    $('#block_form').submit()