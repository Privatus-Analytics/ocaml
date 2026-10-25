open Tyxml

let to_attribs pairs =
  List.map
    (fun (name, value) ->
      let len = String.length name in
      Html.a_user_data (String.sub name 5 (len - 5)) value)
    pairs

let event ?props name = to_attribs (Privatus_analytics.event_data ?props name)
let click name = to_attribs (Privatus_analytics.click_data name)

let tag ?config ?queue_stub ?props ?nonce () =
  Html.Unsafe.data (Privatus_analytics.tag ?config ?queue_stub ?props ?nonce ())
