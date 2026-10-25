module P = Privatus_analytics
module D = Privatus_analytics_dream

let snippet =
  {|<script defer src="https://privatusstats.com/js/pa.js" data-site="pa_TEST123456"></script>|}

let plain = "<html><head><title>Plain</title></head><body>Hi</body></html>"

let config ?(auto_inject = false) ?(queue_stub = false) ?(props = []) ?enabled
    () =
  P.Config.make ~site_id:"pa_TEST123456" ?enabled ~auto_inject ~queue_stub
    ~props ()

let on = config ~enabled:true ()
let inject = config ~enabled:true ~auto_inject:true ()

let router =
  Dream.router
    [
      Dream.get "/" (fun request -> Dream.html (Pages.layout request));
      Dream.get "/features" (fun request -> Dream.html (Pages.features request));
      Dream.get "/plain" (fun _ -> Dream.html plain);
      Dream.get "/sized" (fun _ ->
          Dream.html
            ~headers:[ ("Content-Length", string_of_int (String.length plain)) ]
            plain);
      Dream.get "/data" (fun _ -> Dream.json {|{"head":"</head>"}|});
      Dream.get "/bare" (fun _ -> Dream.html "<p>No head here</p>");
      Dream.get "/gzip" (fun _ ->
          Dream.html ~headers:[ ("Content-Encoding", "gzip") ] plain);
      Dream.get "/missing" (fun _ -> Dream.html ~status:`Not_Found plain);
      Dream.get "/stream" (fun _ ->
          Dream.stream
            ~headers:[ ("Content-Type", "text/html") ]
            (fun stream ->
              Lwt.bind (Dream.write stream plain) (fun () -> Dream.close stream)));
    ]

let get ?(headers = []) ?props ?nonce ~config target =
  let response =
    Dream.test
      (D.middleware ~config ?props ?nonce router)
      (Dream.request ~target ~headers "")
  in
  (response, Lwt_main.run (Dream.body response))

let contains s sub =
  let n = String.length sub and m = String.length s in
  let rec go i = i + n <= m && (String.sub s i n = sub || go (i + 1)) in
  go 0

let count sub s =
  let n = String.length sub in
  let rec go i acc =
    if i + n > String.length s then acc
    else if String.sub s i n = sub then go (i + n) (acc + 1)
    else go (i + 1) acc
  in
  go 0 0

let find sub s =
  let n = String.length sub in
  let rec go i =
    if i + n > String.length s then None
    else if String.sub s i n = sub then Some i
    else go (i + 1)
  in
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

let helper_in_layout () =
  let _, body = get ~config:on "/" in
  has "tag" body snippet;
  Alcotest.(check bool)
    "in head" true
    (Option.get (find snippet body) < Option.get (find "</head>" body))

let helper_off_by_default () =
  with_env "PRIVATUS_ENV" "development" (fun () ->
      let _, body = get ~config:(config ()) "/" in
      lacks "off" body "pa.js")

let helper_on_in_production () =
  with_env "PRIVATUS_ENV" "production" (fun () ->
      let _, body = get ~config:(config ()) "/" in
      has "on" body snippet)

let helper_without_middleware () =
  let body =
    Lwt_main.run
      (Dream.body
         (Dream.test
            (fun request -> Dream.html (Pages.layout request))
            (Dream.request "")))
  in
  lacks "no site id" body "pa.js"

let middleware_off_by_default () =
  let _, body = get ~config:on "/plain" in
  lacks "off" body "pa.js"

let middleware_injects () =
  let _, body = get ~config:inject "/plain" in
  has "injected" body (snippet ^ "\n</head>")

let content_length () =
  let response, body = get ~config:inject "/sized" in
  has "injected" body snippet;
  Alcotest.(check (option string))
    "length"
    (Some (string_of_int (String.length body)))
    (Dream.header response "Content-Length")

let no_second_tag () =
  let _, body = get ~config:inject "/" in
  Alcotest.(check int) "one" 1 (count "/js/pa.js" body)

let leaves_alone path () =
  let _, body = get ~config:inject path in
  lacks path body "pa.js"

let bare () =
  let _, body = get ~config:inject "/bare" in
  Alcotest.(check string) "same" "<p>No head here</p>" body

let ajax () =
  let _, body =
    get ~config:inject
      ~headers:[ ("X-Requested-With", "XMLHttpRequest") ]
      "/plain"
  in
  lacks "ajax" body "pa.js"

let not_enabled () =
  with_env "PRIVATUS_ENV" "" (fun () ->
      let _, body = get ~config:(config ~auto_inject:true ()) "/plain" in
      lacks "off" body "pa.js")

let streamed () =
  let _, body = get ~config:inject "/stream" in
  has "streamed" body (snippet ^ "\n</head>")

let event_and_click () =
  let _, body = get ~config:on "/features" in
  has "event" body
    {|<button data-privatus-event="Export CSV" data-privatus-prop-format="csv">Export</button>|};
  has "click" body
    {|<a data-privatus-click="pricing.cta" href="/pricing">Pricing</a>|}

let props_from_request () =
  let props request =
    [
      ( "plan",
        match Dream.query request "plan" with
        | Some p -> `String p
        | None -> `Null );
    ]
  in
  let _, body = get ~config:on ~props "/?plan=pro" in
  has "props" body
    {|window.privatusPageProps=function(){return {"plan":"pro"}}|};
  has "data-props" body {|data-props="privatusPageProps"|}

let props_in_middleware () =
  let props request = [ ("section", `String (Dream.target request)) ] in
  let _, body = get ~config:inject ~props "/plain" in
  has "props" body {|{"section":"/plain"}|};
  has "data-props" body {|data-props="privatusPageProps"|}

let props_not_called_when_off () =
  let props _ = failwith "should not run" in
  let _, body =
    get ~config:(config ~enabled:false ~auto_inject:true ()) ~props "/"
  in
  lacks "off" body "pa.js"

let nonce_and_stub () =
  let config =
    config ~enabled:true ~auto_inject:true ~queue_stub:true
      ~props:[ ("plan", `String "pro") ]
      ()
  in
  let response, body = get ~config ~nonce:(fun _ -> Some "n0nce") "/sized" in
  Alcotest.(check int) "three nonces" 3 (count {|nonce="n0nce"|} body);
  has "stub" body "q:[]";
  Alcotest.(check (option string))
    "length"
    (Some (string_of_int (String.length body)))
    (Dream.header response "Content-Length")

let per_call_override () =
  let request = Dream.request "" in
  has "override"
    (D.tag ~config:on ~modules:[ "vitals" ]
       ~props:[ ("plan", `String "pro") ]
       request)
    {|data-modules="vitals"|};
  Alcotest.(check string) "off" "" (D.tag ~config:on ~enabled:false request)

let invalid_click () =
  Alcotest.(check string) "nothing" "" (D.click_attr "not valid")

let () =
  let t name f = Alcotest.test_case name `Quick f in
  Alcotest.run "privatus-analytics-dream"
    [
      ( "helpers",
        [
          t "the tag prints in the layout head" helper_in_layout;
          t "nothing outside production by default" helper_off_by_default;
          t "prints when PRIVATUS_ENV is production" helper_on_in_production;
          t "nothing without the middleware or a site id"
            helper_without_middleware;
          t "event and click helpers in a template" event_and_click;
          t "props from the request" props_from_request;
          t "per call overrides" per_call_override;
          t "an invalid click name prints nothing" invalid_click;
        ] );
      ( "middleware",
        [
          t "does nothing by default" middleware_off_by_default;
          t "adds the tag to the head" middleware_injects;
          t "fixes Content-Length" content_length;
          t "no second tag when the layout has one" no_second_tag;
          t "leaves JSON alone" (leaves_alone "/data");
          t "leaves encoded responses alone" (leaves_alone "/gzip");
          t "leaves non-200 responses alone" (leaves_alone "/missing");
          t "leaves HTML without a head alone" bare;
          t "leaves Ajax requests alone" ajax;
          t "adds nothing when not enabled" not_enabled;
          t "works with streamed HTML" streamed;
          t "calls the props function with the request" props_in_middleware;
          t "props function not called when off" props_not_called_when_off;
          t "adds the nonce and the queue stub" nonce_and_stub;
        ] );
    ]
