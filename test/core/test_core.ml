module P = Privatus_analytics

let site = "pa_TEST123456"

let snippet =
  {|<script defer src="https://privatusstats.com/js/pa.js" data-site="pa_TEST123456"></script>|}

let on = P.Config.make ~site_id:site ~enabled:true ()
let str = Alcotest.(check string)

let contains s sub =
  let n = String.length sub and m = String.length s in
  let rec go i = i + n <= m && (String.sub s i n = sub || go (i + 1)) in
  go 0

let has msg s sub =
  if not (contains s sub) then
    Alcotest.failf "%s: %S does not contain %S" msg s sub

let lacks msg s sub =
  if contains s sub then Alcotest.failf "%s: %S contains %S" msg s sub

let with_env name value f =
  let old = Sys.getenv_opt name in
  Unix.putenv name value;
  Fun.protect f ~finally:(fun () ->
      Unix.putenv name (Option.value old ~default:""))

(* The tag *)

let basic () = str "snippet" snippet (P.tag ~config:on ())

let no_site_id () =
  with_env "PRIVATUS_SITE_ID" "" (fun () ->
      str "empty" "" (P.tag ~config:(P.Config.make ~enabled:true ()) ()))

let site_id_from_env () =
  with_env "PRIVATUS_SITE_ID" " pa_FROMENV " (fun () ->
      has "env"
        (P.tag ~config:(P.Config.make ~enabled:true ()) ())
        {|data-site="pa_FROMENV"|})

let disabled_by_default () =
  with_env "PRIVATUS_ENV" "development" (fun () ->
      str "off" "" (P.tag ~config:(P.Config.make ~site_id:site ()) ()))

let enabled_in_production () =
  with_env "PRIVATUS_ENV" "production" (fun () ->
      str "on" snippet (P.tag ~config:(P.Config.make ~site_id:site ()) ());
      str "forced off" ""
        (P.tag ~config:(P.Config.make ~site_id:site ~enabled:false ()) ()))

let script_host () =
  let config =
    P.Config.make ~site_id:site ~enabled:true
      ~script_host:"https://cdn.example.com/" ()
  in
  has "host" (P.tag ~config ()) {|src="https://cdn.example.com/js/pa.js"|};
  with_env "PRIVATUS_SCRIPT_HOST" "https://env.example.com" (fun () ->
      has "env host" (P.tag ~config:on ())
        {|src="https://env.example.com/js/pa.js"|})

let modules_and_exclusions () =
  let tag =
    P.tag ~config:on ~modules:[ "engage"; "auto" ]
      ~excluded_paths:[ "/admin/*"; "/preview/*" ]
      ()
  in
  has "modules" tag {|data-modules="engage,auto"|};
  has "exclude" tag {|data-exclude="/admin/*,/preview/*"|}

let empty_modules () =
  has "none" (P.tag ~config:on ~modules:[] ()) {|data-modules=""|}

let domains_spa_manual () =
  let config =
    {
      on with
      domains = [ "example.com, www.example.com" ];
      spa = `Hash;
      manual = true;
    }
  in
  let tag = P.tag ~config () in
  has "domains" tag {|data-domains="example.com,www.example.com"|};
  has "spa" tag {|data-spa="hash"|};
  has "manual" tag {|data-manual="true"|};
  lacks "auto spa" (P.tag ~config:on ~spa:`Auto ()) "data-spa"

let escapes_values () =
  has "escaped"
    (P.tag ~config:on ~excluded_paths:[ {|/a"b|} ] ())
    {|data-exclude="/a&quot;b"|}

let per_call_overrides () =
  let config = { on with modules = Some [ "engage" ] } in
  has "override"
    (P.tag ~config ~modules:[ "vitals" ] ())
    {|data-modules="vitals"|};
  str "site id override" "" (P.tag ~config ~enabled:false ());
  has "site override"
    (P.tag ~config ~site_id:"pa_OTHER" ())
    {|data-site="pa_OTHER"|}

let extra_attributes_and_nonce () =
  let config =
    {
      on with
      extra_attributes =
        [ ("data-mask", "/orders/*->/orders/:id"); ("bad name", "x") ];
    }
  in
  let tag = P.tag ~config ~nonce:"abc123" () in
  has "mask" tag {|data-mask="/orders/*-&gt;/orders/:id"|};
  has "nonce" tag {|nonce="abc123"|};
  lacks "bad name" tag "bad name"

let page_props_script () =
  let html =
    P.tag ~config:on
      ~props:[ ("plan", `String "pro"); ("role", `String "admin") ]
      ()
  in
  str "props"
    ({|<script>window.privatusPageProps=function(){return {"plan":"pro","role":"admin"}}</script>|}
   ^ "\n"
   ^ {|<script defer src="https://privatusstats.com/js/pa.js" data-site="pa_TEST123456" data-props="privatusPageProps"></script>|}
    )
    html

let props_script_nonce () =
  let html =
    P.tag ~config:on ~props:[ ("plan", `String "pro") ] ~nonce:"abc" ()
  in
  has "nonce" html {|<script nonce="abc">window.privatusPageProps=|};
  Alcotest.(check bool)
    "starts" true
    (String.sub html 0 19 = {|<script nonce="abc"|})

let empty_props () =
  lacks "none"
    (P.tag ~config:on ~props:[ ("plan", `Null) ] ())
    "privatusPageProps"

let configured_props () =
  has "config"
    (P.tag ~config:{ on with props = [ ("plan", `String "pro") ] } ())
    {|{"plan":"pro"}|}

let merged_props () =
  let config =
    { on with props = [ ("plan", `String "pro"); ("role", `String "admin") ] }
  in
  has "merged"
    (P.tag ~config ~props:[ ("Role", `Null); ("tier", `String "gold") ] ())
    {|{"plan":"pro","tier":"gold"}|}

let props_fn () =
  let config =
    { on with props = [ ("plan", `String "pro"); ("role", `String "admin") ] }
  in
  let html =
    P.tag ~config
      ~props_fn:(fun () -> [ ("plan", `String "team") ])
      ~props:[ ("role", `Null) ]
      ()
  in
  has "fn" html {|{"plan":"team"}|};
  str "not called when off" ""
    (P.tag
       ~config:{ config with enabled = Some false }
       ~props_fn:(fun () -> failwith "should not run")
       ())

let queue_stub_first () =
  let config = { on with queue_stub = true } in
  let html = P.tag ~config ~nonce:"abc" ~props:[ ("plan", `String "pro") ] () in
  match String.split_on_char '\n' html with
  | [ a; b; c ] ->
      str "stub" ({|<script nonce="abc">|} ^ P.queue_stub ^ "</script>") a;
      has "props" b "privatusPageProps";
      has "tag" c "/js/pa.js"
  | _ -> Alcotest.fail html

let official_stub () =
  str "stub"
    "window.privatus=window.privatus||{q:[]};['track','pageview','props','optOut','optIn','ready'].forEach(function(m){window.privatus[m]=window.privatus[m]||function(){window.privatus.q.push([m,Array.prototype.slice.call(arguments)])}})"
    P.queue_stub

let stub_per_call () =
  has "on" (P.tag ~config:on ~queue_stub:true ()) "q:[]";
  lacks "off" (P.tag ~config:on ()) "q:[]"

let stub_only nonce =
  {|<script nonce="|} ^ nonce ^ {|">|} ^ P.queue_stub ^ "</script>"

let boom () = failwith "should not run"

let off_with_stub () =
  str "only the stub, with the nonce" (stub_only "abc")
    (P.tag
       ~config:{ on with props = [ ("role", `String "admin") ] }
       ~enabled:false ~queue_stub:true ~nonce:"abc"
       ~props:[ ("plan", `String "pro") ]
       ~props_fn:boom ());
  str "no nonce"
    ("<script>" ^ P.queue_stub ^ "</script>")
    (P.tag ~config:on ~enabled:false ~queue_stub:true ())

let off_without_stub () =
  str "nothing" ""
    (P.tag ~config:on ~enabled:false ~nonce:"abc"
       ~props:[ ("plan", `String "pro") ]
       ())

let no_site_id_with_stub () =
  with_env "PRIVATUS_SITE_ID" "" (fun () ->
      str "only the stub" (stub_only "abc")
        (P.tag
           ~config:(P.Config.make ~enabled:true ~queue_stub:true ())
           ~nonce:"abc"
           ~props:[ ("plan", `String "pro") ]
           ~props_fn:boom ()))

let default_off_with_stub () =
  with_env "PRIVATUS_ENV" "development" (fun () ->
      str "only the stub"
        ("<script>" ^ P.queue_stub ^ "</script>")
        (P.tag ~config:(P.Config.make ~site_id:site ~queue_stub:true ()) ()))

(* Page props JSON *)

let json = Alcotest.(check (option string))

let props_object () =
  json "object" (Some {|{"plan":"pro","role":"admin"}|})
    (P.page_props_json [ ("plan", `String "pro"); ("role", `String "admin") ])

let props_empty () =
  json "empty" None (P.page_props_json []);
  json "null" None (P.page_props_json [ ("gone", `Null) ])

let props_types () =
  json "types"
    (Some
       {|{"seats":5,"ratio":1.5,"beta":true,"old":false,"flags":["a","b",3]}|})
    (P.page_props_json
       [
         ("seats", `Int 5);
         ("ratio", `Float 1.5);
         ("beta", `Bool true);
         ("old", `Bool false);
         ("flags", `List [ `String "a"; `Null; `String "b"; `Int 3 ]);
       ])

let props_keys () =
  json "keys" (Some {|{"app_version":"2.1"}|})
    (P.page_props_json [ ("App Version", `String "2.1") ])

let count sub s =
  let n = String.length sub in
  let rec go i acc =
    if i + n > String.length s then acc
    else if String.sub s i n = sub then go (i + n) (acc + 1)
    else go (i + 1) acc
  in
  go 0 0

let props_limits () =
  let many = List.init 40 (fun i -> (Printf.sprintf "p%d" (i + 1), `Int i)) in
  let j = Option.get (P.page_props_json many) in
  Alcotest.(check int) "30 props" 30 (count ":" j);
  let list = List.init 50 (fun i -> `String (string_of_int i)) in
  let j = Option.get (P.page_props_json [ ("list", `List list) ]) in
  Alcotest.(check int) "30 items" 30 ((count "\"" j / 2) - 1);
  let j =
    Option.get (P.page_props_json [ ("long", `String (String.make 900 'x')) ])
  in
  Alcotest.(check int) "500 chars" 500 (count "x" j);
  json "no nan" None (P.page_props_json [ ("bad", `Float Float.nan) ])

let props_safe () =
  let j =
    P.page_props_json
      [ ("note", `String "</script><b>&\xe2\x80\xa8\xe2\x80\xa9\"\\\n") ]
  in
  json "safe"
    (Some
       {|{"note":"\u003c/script\u003e\u003cb\u003e\u0026\u2028\u2029\"\\\n"}|})
    j

let props_unicode () =
  json "utf8" (Some "{\"city\":\"Z\xc3\xbcrich\",\"x\":\"\xef\xbf\xbd\"}")
    (P.page_props_json
       [ ("city", `String "Z\xc3\xbcrich"); ("x", `String "\xff") ])

(* Event attributes *)

let pairs = Alcotest.(check (list (pair string string)))

let event_basic () =
  pairs "event"
    [
      ("data-privatus-event", "Export CSV");
      ("data-privatus-prop-format", "csv");
      ("data-privatus-prop-source", "toolbar");
    ]
    (P.event_data "Export CSV"
       ~props:[ ("format", `String "csv"); ("source", `String "toolbar") ]);
  str "html"
    {|data-privatus-event="Export CSV" data-privatus-prop-format="csv" data-privatus-prop-source="toolbar"|}
    (P.event_attrs "Export CSV"
       ~props:[ ("format", `String "csv"); ("source", `String "toolbar") ])

let event_name () =
  pairs "trim"
    [ ("data-privatus-event", "Export CSV") ]
    (P.event_data "  Export CSV  ");
  pairs "cut"
    [ ("data-privatus-event", String.make 120 'a') ]
    (P.event_data (String.make 200 'a'));
  pairs "unicode cut"
    [
      ( "data-privatus-event",
        String.concat "" (List.init 120 (fun _ -> "\xc3\xa9")) );
    ]
    (P.event_data (String.concat "" (List.init 130 (fun _ -> "\xc3\xa9"))))

let event_empty () =
  pairs "empty" [] (P.event_data "   " ~props:[ ("format", `String "csv") ]);
  str "empty html" "" (P.event_attrs "")

let event_keys () =
  let attrs =
    P.event_data "Saved"
      ~props:
        [
          ("Report Type", `String "a");
          ("x-y", `String "b");
          (String.make 80 'K', `String "c");
        ]
  in
  pairs "keys"
    [
      ("data-privatus-event", "Saved");
      ("data-privatus-prop-report_type", "a");
      ("data-privatus-prop-x_y", "b");
      ("data-privatus-prop-" ^ String.make 64 'k', "c");
    ]
    attrs

let event_values () =
  pairs "values"
    [
      ("data-privatus-event", "Saved");
      ("data-privatus-prop-on", "true");
      ("data-privatus-prop-off", "false");
      ("data-privatus-prop-count", "3");
      ("data-privatus-prop-ratio", "1.5");
      ("data-privatus-prop-tags", "a,b");
    ]
    (P.event_data "Saved"
       ~props:
         [
           ("on", `Bool true);
           ("off", `Bool false);
           ("count", `Int 3);
           ("ratio", `Float 1.5);
           ("tags", `List [ `String "a"; `Null; `String "b" ]);
           ("gone", `Null);
         ])

let event_limits () =
  let props =
    List.init 40 (fun i -> (Printf.sprintf "p%d" (i + 1), `String "v"))
  in
  Alcotest.(check int) "31 attrs" 31 (List.length (P.event_data "Saved" ~props));
  let long =
    P.event_data "Saved" ~props:[ ("long", `String (String.make 900 'x')) ]
  in
  Alcotest.(check int)
    "500" 500
    (String.length (List.assoc "data-privatus-prop-long" long))

let event_escape () =
  str "escape"
    {|data-privatus-event="Say &quot;hi&quot; &lt;now&gt;" data-privatus-prop-note="a&amp;b"|}
    (P.event_attrs {|Say "hi" <now>|} ~props:[ ("note", `String "a&b") ])

let event_when_off () =
  with_env "PRIVATUS_ENV" "development" (fun () ->
      has "still prints" (P.event_attrs "Saved") {|data-privatus-event="Saved"|})

(* Click maps *)

let click_valid () =
  str "valid" {|data-privatus-click="pricing.cta"|} (P.click_attr "pricing.cta");
  pairs "chars"
    [ ("data-privatus-click", "a-b_c:d.1") ]
    (P.click_data "a-b_c:d.1")

let click_invalid () =
  List.iter
    (fun name -> str name "" (P.click_attr name))
    [ ""; "has space"; String.make 101 'x'; "<b>"; "\xc3\xa9" ]

(* Injection *)

let inject () =
  let html = "<html><HEAD><title>x</title></HEAD><body></body></html>" in
  Alcotest.(check (option string))
    "before head"
    (Some "<html><HEAD><title>x</title>TAG\n</HEAD><body></body></html>")
    (P.inject_html ~tag:"TAG" html);
  Alcotest.(check (option string))
    "no head" None
    (P.inject_html ~tag:"TAG" "<p>hi</p>");
  Alcotest.(check (option string))
    "has tag" None
    (P.inject_html ~tag:"TAG" "<head><script src=\"/js/pa.js\"></script></head>");
  Alcotest.(check (option string)) "empty tag" None (P.inject_html ~tag:"" html)

let () =
  let t name f = Alcotest.test_case name `Quick f in
  Alcotest.run "privatus-analytics"
    [
      ( "tag",
        [
          t "prints the basic snippet" basic;
          t "prints nothing without a site id" no_site_id;
          t "reads the site id from PRIVATUS_SITE_ID" site_id_from_env;
          t "prints nothing outside production by default" disabled_by_default;
          t "prints in production and enabled forces it" enabled_in_production;
          t "script host setting and env" script_host;
          t "adds modules and exclusions" modules_and_exclusions;
          t "an empty modules list loads none" empty_modules;
          t "adds domains, spa mode and manual mode" domains_spa_manual;
          t "escapes attribute values" escapes_values;
          t "per call options override the settings" per_call_overrides;
          t "adds extra attributes and a nonce" extra_attributes_and_nonce;
          t "page props print a script and data-props" page_props_script;
          t "the props script gets the nonce" props_script_nonce;
          t "empty props print no script" empty_props;
          t "configured props" configured_props;
          t "per call props merge and Null removes" merged_props;
          t "props_fn is merged and lazy" props_fn;
          t "queue stub prints first" queue_stub_first;
          t "the queue stub is the official one" official_stub;
          t "queue stub per call" stub_per_call;
          t "off with the stub on prints only the stub" off_with_stub;
          t "off with the stub off prints nothing" off_without_stub;
          t "no site id with the stub on prints only the stub"
            no_site_id_with_stub;
          t "outside production the stub still prints" default_off_with_stub;
        ] );
      ( "page props",
        [
          t "props become a JSON object" props_object;
          t "empty props give None" props_empty;
          t "numbers, booleans and lists keep their types" props_types;
          t "keys are cleaned like event props" props_keys;
          t "limits props, items and length" props_limits;
          t "the JSON is safe inside a script" props_safe;
          t "unicode is kept and bad bytes replaced" props_unicode;
        ] );
      ( "events",
        [
          t "an event becomes data attributes" event_basic;
          t "the name is trimmed and cut" event_name;
          t "an empty name gives nothing" event_empty;
          t "keys are lowercased, cleaned and cut" event_keys;
          t "values become strings, Null dropped" event_values;
          t "values cut, at most 30 props" event_limits;
          t "html escapes every value" event_escape;
          t "prints even when the tag is off" event_when_off;
        ] );
      ( "clicks",
        [
          t "a valid name" click_valid;
          t "invalid names give nothing" click_invalid;
        ] );
      ("inject", [ t "puts the tag before </head>" inject ]);
    ]
