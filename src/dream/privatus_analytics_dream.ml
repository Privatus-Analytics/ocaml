module P = Privatus_analytics

type context = {
  config : P.Config.t;
  props : (Dream.request -> P.props) option;
  nonce : (Dream.request -> string option) option;
}

let field : context Dream.field = Dream.new_field ~name:"privatus_analytics" ()
let default_context = { config = P.Config.default; props = None; nonce = None }

let context request =
  match Dream.field request field with Some c -> c | None -> default_context

let tag ?config ?site_id ?script_host ?modules ?excluded_paths ?domains ?spa
    ?manual ?enabled ?extra_attributes ?queue_stub ?props ?nonce request =
  let ctx = context request in
  let config = Option.value config ~default:ctx.config in
  let nonce =
    match nonce with
    | Some _ -> nonce
    | None -> ( match ctx.nonce with Some f -> f request | None -> None)
  in
  let props_fn = Option.map (fun f () -> f request) ctx.props in
  P.tag ~config ?site_id ?script_host ?modules ?excluded_paths ?domains ?spa
    ?manual ?enabled ?extra_attributes ?queue_stub ?props ?props_fn ?nonce ()

let event_attrs = P.event_attrs

let click_attr name =
  if
    (not (P.valid_click name))
    && Sys.getenv_opt "PRIVATUS_ENV" <> Some "production"
  then
    Dream.warning (fun log ->
        log
          "[privatus-analytics] click map name %S is not valid. Use letters, \
           digits and _ . : - only, at most 100 characters. Nothing was \
           printed."
          name);
  P.click_attr name

let starts_with ~prefix s =
  String.length s >= String.length prefix
  && String.sub s 0 (String.length prefix) = prefix

let html_response response =
  match Dream.header response "Content-Type" with
  | Some t ->
      starts_with ~prefix:"text/html" (String.lowercase_ascii (String.trim t))
  | None -> false

let ajax request =
  match Dream.header request "X-Requested-With" with
  | Some v -> String.lowercase_ascii (String.trim v) = "xmlhttprequest"
  | None -> false

let should_inject (config : P.Config.t) request response =
  config.auto_inject
  && Dream.status_to_int (Dream.status response) = 200
  && html_response response
  && Dream.header response "Content-Encoding" = None
  && (not (ajax request))
  && P.Config.renders config

let middleware ?(config = P.Config.default) ?props ?nonce inner request =
  Dream.set_field request field { config; props; nonce };
  Lwt.bind (inner request) (fun response ->
      if not (should_inject config request response) then Lwt.return response
      else
        Lwt.bind (Dream.body response) (fun html ->
            (match P.inject_html ~tag:(tag request) html with
            | Some html ->
                Dream.set_body response html;
                if Dream.has_header response "Content-Length" then
                  Dream.set_header response "Content-Length"
                    (string_of_int (String.length html))
            | None -> Dream.set_body response html);
            Lwt.return response))
