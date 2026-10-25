open Tyxml

let to_string elt = Format.asprintf "%a" (Html.pp_elt ()) elt

let event_button () =
  let button =
    Html.button
      ~a:
        (Privatus_analytics_tyxml.event
           ~props:[ ("format", `String "csv") ]
           "Export CSV")
      [ Html.txt "Export" ]
  in
  Alcotest.(check string)
    "button"
    {|<button data-privatus-event="Export CSV" data-privatus-prop-format="csv">Export</button>|}
    (to_string button)

let click_link () =
  let link =
    Html.a
      ~a:(Html.a_href "/pricing" :: Privatus_analytics_tyxml.click "pricing.cta")
      [ Html.txt "Pricing" ]
  in
  Alcotest.(check string)
    "link" {|<a href="/pricing" data-privatus-click="pricing.cta">Pricing</a>|}
    (to_string link);
  Alcotest.(check int)
    "invalid" 0
    (List.length (Privatus_analytics_tyxml.click "no spaces"))

let script_tag () =
  let config =
    Privatus_analytics.Config.make ~site_id:"pa_TEST123456" ~enabled:true ()
  in
  let head =
    Html.head
      (Html.title (Html.txt "x"))
      [ Privatus_analytics_tyxml.tag ~config () ]
  in
  Alcotest.(check string)
    "head"
    {|<head><title>x</title><script defer src="https://privatusstats.com/js/pa.js" data-site="pa_TEST123456"></script></head>|}
    (to_string head)

let () =
  Alcotest.run "privatus-analytics.tyxml"
    [
      ( "tyxml",
        [
          Alcotest.test_case "event attributes on a button" `Quick event_button;
          Alcotest.test_case "click map name on a link" `Quick click_link;
          Alcotest.test_case "script tag in the head" `Quick script_tag;
        ] );
    ]
