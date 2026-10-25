(** Prints the cookieless Privatus Analytics tracking script and the HTML
    attributes the tracker reads.

    This library only builds HTML text. It never sends events from your server,
    never makes web requests, sets no cookies and reads no IP addresses or
    browser details.

    {[
    let config = Privatus_analytics.Config.make ~site_id:"pa_YOURSITEID" ()
    let head = Privatus_analytics.tag ~config ()
    ]}

    In production it gives:
    {v
    <script defer src="https://privatusstats.com/js/pa.js" data-site="pa_YOURSITEID"></script>
    v}

    See {{:https://privatusanalytics.com/docs} the Privatus Analytics docs} and
    the
    {{:https://privatusanalytics.com/docs/tracker/attributes} script attributes
     reference}. *)

val version : string
(** The library version, ["1.0.0"]. *)

(** {1 Values} *)

type value =
  [ `String of string
  | `Int of int
  | `Float of float
  | `Bool of bool
  | `List of value list
  | `Null ]
(** A prop value. [`Null] leaves the prop out (and, in per call page props,
    removes a configured one). *)

type props = (string * value) list
(** Props as key and value pairs, for example
    [[ ("plan", `String "pro"); ("seats", `Int 5) ]].

    Never put names, emails, user ids or anything else that points to one person
    in props. Put groups (like the plan or the role), not people. *)

type spa = [ `Auto | `History | `Hash | `Off ]
(** Single page app mode. Only modes other than [`Auto] print a [data-spa]
    attribute. *)

(** {1 Settings} *)

module Config : sig
  type t = {
    site_id : string option;
        (** The [data-site] attribute (starts with [pa_]). [None] falls back to
            the [PRIVATUS_SITE_ID] environment variable. Nothing prints without
            it. *)
    script_host : string option;
        (** Where [/js/pa.js] is served. [None] falls back to
            [PRIVATUS_SCRIPT_HOST], then [https://privatusstats.com]. A trailing
            slash is removed. *)
    modules : string list option;
        (** The [data-modules] attribute. [None] keeps the tracker default,
            [Some []] loads none. *)
    excluded_paths : string list;  (** The [data-exclude] attribute. *)
    domains : string list;  (** The [data-domains] attribute. *)
    spa : spa;  (** The [data-spa] attribute. *)
    manual : bool;  (** [true] prints [data-manual="true"]. *)
    enabled : bool option;
        (** [Some true] or [Some false] forces the tag on or off. [None] turns
            it on only when the [PRIVATUS_ENV] environment variable is
            ["production"]. *)
    auto_inject : bool;
        (** Used by framework middleware: [true] adds the tag to the head of
            HTML pages. *)
    extra_attributes : (string * string) list;
        (** Any other attributes, for example
            [[ ("data-mask", "/orders/*->/orders/:id") ]]. *)
    props : props;  (** Page props sent with every pageview and event. *)
    queue_stub : bool;
        (** [true] prints the tracker's queue stub first, so [privatus.track]
            calls made before [pa.js] loads are kept. It also prints when the
            tag is off (then nothing else prints), so those calls never fail. *)
  }

  val default : t
  (** Every setting at its default. *)

  val make :
    ?site_id:string ->
    ?script_host:string ->
    ?modules:string list ->
    ?excluded_paths:string list ->
    ?domains:string list ->
    ?spa:spa ->
    ?manual:bool ->
    ?enabled:bool ->
    ?auto_inject:bool ->
    ?extra_attributes:(string * string) list ->
    ?props:props ->
    ?queue_stub:bool ->
    unit ->
    t
  (** Builds settings. Anything you leave out keeps its default. *)

  val site_id : t -> string option
  (** The site id after the environment variable fallback. *)

  val script_host : t -> string
  (** The script host after the fallbacks, without a trailing slash. *)

  val enabled : t -> bool
  (** Whether the tag is on. *)

  val renders : t -> bool
  (** Whether a tag prints: there is a site id and the tag is on. *)
end

(** {1 The script tag} *)

val tag :
  ?config:Config.t ->
  ?site_id:string ->
  ?script_host:string ->
  ?modules:string list ->
  ?excluded_paths:string list ->
  ?domains:string list ->
  ?spa:spa ->
  ?manual:bool ->
  ?enabled:bool ->
  ?extra_attributes:(string * string) list ->
  ?queue_stub:bool ->
  ?props:props ->
  ?props_fn:(unit -> props) ->
  ?nonce:string ->
  unit ->
  string
(** The HTML for the head of your page. When there is no site id or the tag is
    off, it is only the queue stub (when [queue_stub] is on) or [""]. Every
    optional argument overrides the matching setting in [config] for this call.

    [props] are merged over the configured props, and a [`Null] value removes
    one. [props_fn] is for framework helpers: its props sit between the
    configured ones and [props], and it is only called when a tag prints.
    [nonce] is your Content Security Policy nonce. It goes on every script tag.

    With page props or [queue_stub], small inline scripts print before the
    tracker tag, one per line. *)

val queue_stub : string
(** The official queue stub script body. *)

val queue_stub_script : ?nonce:string -> unit -> string
(** The queue stub in a [<script>] tag. *)

val page_props_json : props -> string option
(** Page props as a JSON object that is safe inside a [<script>] tag, or [None]
    when no props are left. Keys follow the event prop rules. Numbers and
    booleans stay JSON numbers and booleans, lists stay lists (at most 30
    items). [<], [>], [&], U+2028 and U+2029 are written as [<] and so on. *)

(** {1 Custom events and click maps} *)

val event_attrs : ?props:props -> string -> string
(** [event_attrs ~props:[ ("format", `String "csv") ] "Export CSV"] is
    [data-privatus-event="Export CSV" data-privatus-prop-format="csv"].

    Put it inside a button, link or form tag. On a form the event is sent when
    the form is submitted. The name is trimmed and cut to 120 characters, and an
    empty name gives [""]. Prop keys are made lowercase, anything other than
    [a-z], [0-9] and [_] becomes [_], and keys are cut to 64 characters. At most
    30 props. Values become text (lists joined with commas) cut to 500
    characters, and [`Null] values are left out. Every value is escaped for
    HTML. The attributes print even when the tag is off. *)

val event_data : ?props:props -> string -> (string * string) list
(** The same attributes as name and value pairs, not escaped, for HTML builders.
    [[]] for an empty name. *)

val click_attr : string -> string
(** [click_attr "pricing.cta"] is [data-privatus-click="pricing.cta"], or [""]
    when the name is not valid. *)

val click_data : string -> (string * string) list
(** The click map attribute as a name and value pair, or [[]]. *)

val valid_click : string -> bool
(** Whether a click map name is valid: 1 to 100 letters, digits or [_ . : -]. *)

(** {1 Helpers} *)

val attrs_to_html : (string * string) list -> string
(** Turns attribute pairs into [name="value"] text with every value escaped. *)

val escape_html : string -> string
(** Escapes ampersands, angle brackets and both kinds of quotes for HTML. *)

val normalize_key : string -> string
(** Cleans one prop key the way the tracker expects. *)

val marker : string
(** ["/js/pa.js"]. A page that contains this already has the tag. *)

val inject_html : tag:string -> string -> string option
(** [inject_html ~tag html] puts [tag] just before the first [</head>] (any
    case). [None] when [tag] is empty, the page already has the tag, or there is
    no [</head>]. Used by framework middleware. *)
