(** Privatus Analytics for {{:https://aantron.github.io/dream/} Dream}.

    Add the middleware once. It keeps your settings for the template helpers,
    and it can also add the tag to every HTML page for you.

    {[
    let config = Privatus_analytics.Config.make ~site_id:"pa_YOURSITEID" ()

    let () =
      Dream.run @@ Dream.logger
      @@ Privatus_analytics_dream.middleware ~config
      @@ Dream.router
           [ Dream.get "/" (fun request -> Dream.html (Page.render request)) ]
    ]}

    In a [.eml] template, print the helpers with [<%s! ... %>] so the HTML is
    not escaped a second time (the helpers escape every value already):

    {v
    <head>
      <%s! Privatus_analytics_dream.tag request %>
    </head>
    <button <%s! Privatus_analytics_dream.event_attrs "Report exported" ~props:[ ("format", `String "csv") ] %>>Export</button>
    <a href="/pricing" <%s! Privatus_analytics_dream.click_attr "pricing.cta" %>>See plans</a>
    v}

    Nothing here sends events from your server, sets cookies or reads IP
    addresses. *)

val middleware :
  ?config:Privatus_analytics.Config.t ->
  ?props:(Dream.request -> Privatus_analytics.props) ->
  ?nonce:(Dream.request -> string option) ->
  Dream.middleware
(** [middleware ~config] keeps [config] on each request for {!tag}.

    [props] is called on each request where a tag prints, after your handler has
    run. Its props are merged over [config.props]. [nonce] gives the Content
    Security Policy nonce for the request, if you use one.

    When [config.auto_inject] is [true], it also adds the tag just before
    [</head>] in responses with status 200, a [text/html] content type and no
    [Content-Encoding] header. It skips Ajax requests (with
    [X-Requested-With: XMLHttpRequest]), pages without a [</head>], and pages
    that already have the tag. It updates [Content-Length] when the response has
    one. *)

val tag :
  ?config:Privatus_analytics.Config.t ->
  ?site_id:string ->
  ?script_host:string ->
  ?modules:string list ->
  ?excluded_paths:string list ->
  ?domains:string list ->
  ?spa:Privatus_analytics.spa ->
  ?manual:bool ->
  ?enabled:bool ->
  ?extra_attributes:(string * string) list ->
  ?queue_stub:bool ->
  ?props:Privatus_analytics.props ->
  ?nonce:string ->
  Dream.request ->
  string
(** The script tag for this request, using the settings, props and nonce from
    {!middleware}. Without the middleware it uses
    {!Privatus_analytics.Config.default}. Each optional argument overrides one
    setting for this call. [props] are merged over the configured props, and
    [`Null] removes one. Without a site id or when the tag is off, it gives only
    the queue stub (when [queue_stub] is on) or [""]. *)

val event_attrs : ?props:Privatus_analytics.props -> string -> string
(** Same as {!Privatus_analytics.event_attrs}. *)

val click_attr : string -> string
(** Same as {!Privatus_analytics.click_attr}. When the name is not valid it
    prints nothing, and outside production it also logs a warning. *)
