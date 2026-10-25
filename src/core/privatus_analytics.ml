let version = "1.0.0"
let default_host = "https://privatusstats.com"
let props_function = "privatusPageProps"
let marker = "/js/pa.js"

let queue_stub =
  "window.privatus=window.privatus||{q:[]};['track','pageview','props','optOut','optIn','ready'].forEach(function(m){window.privatus[m]=window.privatus[m]||function(){window.privatus.q.push([m,Array.prototype.slice.call(arguments)])}})"

let max_name = 120
let max_key = 64
let max_props = 30
let max_value = 500
let max_items = 30

type value =
  [ `String of string
  | `Int of int
  | `Float of float
  | `Bool of bool
  | `List of value list
  | `Null ]

type props = (string * value) list
type spa = [ `Auto | `History | `Hash | `Off ]

(* Text helpers *)

let escape_html s =
  let b = Buffer.create (String.length s + 16) in
  String.iter
    (function
      | '&' -> Buffer.add_string b "&amp;"
      | '<' -> Buffer.add_string b "&lt;"
      | '>' -> Buffer.add_string b "&gt;"
      | '"' -> Buffer.add_string b "&quot;"
      | '\'' -> Buffer.add_string b "&#39;"
      | c -> Buffer.add_char b c)
    s;
  Buffer.contents b

(* Calls [f] on each UTF-8 character of [s]. Bad bytes come through as
   U+FFFD, one call each. *)
let iter_utf_8 f s =
  let len = String.length s in
  let rec go i =
    if i < len then (
      let d = String.get_utf_8_uchar s i in
      let u =
        if Uchar.utf_decode_is_valid d then Uchar.utf_decode_uchar d
        else Uchar.rep
      in
      f u;
      go (i + Uchar.utf_decode_length d))
  in
  go 0

(* Cuts [s] to at most [n] characters and replaces bad UTF-8 bytes. *)
let cut n s =
  let b = Buffer.create (min (String.length s) (n * 4)) in
  let count = ref 0 in
  iter_utf_8
    (fun u ->
      if !count < n then (
        Buffer.add_utf_8_uchar b u;
        incr count))
    s;
  Buffer.contents b

(* Like Stdlib's [List.assoc] update: replaces a key in place or appends it. *)
let set key v pairs =
  if List.mem_assoc key pairs then
    List.map (fun (k, old) -> if k = key then (k, v) else (k, old)) pairs
  else pairs @ [ (key, v) ]

let rec take n = function
  | [] -> []
  | _ when n <= 0 -> []
  | x :: rest -> x :: take (n - 1) rest

let normalize_key key =
  let b = Buffer.create (String.length key) in
  iter_utf_8
    (fun u ->
      let c = Uchar.to_int u in
      let c = if c >= Char.code 'A' && c <= Char.code 'Z' then c + 32 else c in
      if
        (c >= Char.code 'a' && c <= Char.code 'z')
        || (c >= Char.code '0' && c <= Char.code '9')
        || c = Char.code '_'
      then Buffer.add_char b (Char.chr c)
      else Buffer.add_char b '_')
    key;
  let s = Buffer.contents b in
  if String.length s > max_key then String.sub s 0 max_key else s

let normalize props =
  let clean =
    List.fold_left
      (fun acc (key, v) ->
        let key = normalize_key key in
        match v with
        | `Null -> acc
        | _ when key = "" -> acc
        | v -> set key v acc)
      [] props
  in
  take max_props clean

let float_text f =
  if Float.is_nan f then "NaN"
  else if f = Float.infinity then "Infinity"
  else if f = Float.neg_infinity then "-Infinity"
  else if Float.is_integer f && Float.abs f < 1e16 then Printf.sprintf "%.1f" f
  else
    let rec go p =
      let s = Printf.sprintf "%.*g" p f in
      if p >= 17 || float_of_string s = f then s else go (p + 1)
    in
    go 15

(* Event attributes and click maps *)

let rec flat_text (v : value) =
  match v with
  | `String s -> Some s
  | `Int i -> Some (string_of_int i)
  | `Float f -> Some (float_text f)
  | `Bool b -> Some (string_of_bool b)
  | `Null -> None
  | `List items -> Some (String.concat "," (List.filter_map flat_text items))

let string_value v =
  match flat_text v with Some s -> cut max_value s | None -> ""

let event_data ?(props = []) name =
  let name = String.trim (cut max_name (String.trim name)) in
  if name = "" then []
  else
    ("data-privatus-event", name)
    :: List.map
         (fun (key, v) -> ("data-privatus-prop-" ^ key, string_value v))
         (normalize props)

let attrs_to_html attrs =
  String.concat " "
    (List.map
       (fun (name, v) -> Printf.sprintf "%s=\"%s\"" name (escape_html v))
       attrs)

let event_attrs ?props name = attrs_to_html (event_data ?props name)

let valid_click name =
  let len = String.length name in
  len >= 1 && len <= 100
  && String.for_all
       (function
         | 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_' | '.' | ':' | '-' -> true
         | _ -> false)
       name

let click_data name =
  if valid_click name then [ ("data-privatus-click", name) ] else []

let click_attr name = attrs_to_html (click_data name)

(* Page props *)

let json_string s =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '"';
  iter_utf_8
    (fun u ->
      match Uchar.to_int u with
      | 0x22 -> Buffer.add_string b "\\\""
      | 0x5c -> Buffer.add_string b "\\\\"
      | 0x0a -> Buffer.add_string b "\\n"
      | 0x0d -> Buffer.add_string b "\\r"
      | 0x09 -> Buffer.add_string b "\\t"
      | 0x08 -> Buffer.add_string b "\\b"
      | 0x0c -> Buffer.add_string b "\\f"
      | (0x3c | 0x3e | 0x26 | 0x2028 | 0x2029) as c ->
          Buffer.add_string b (Printf.sprintf "\\u%04x" c)
      | c when c < 0x20 -> Buffer.add_string b (Printf.sprintf "\\u%04x" c)
      | _ -> Buffer.add_utf_8_uchar b u)
    s;
  Buffer.add_char b '"';
  Buffer.contents b

let json_scalar (v : value) =
  match v with
  | `String s -> Some (json_string (cut max_value s))
  | `Int i -> Some (string_of_int i)
  | `Float f -> if Float.is_finite f then Some (float_text f) else None
  | `Bool b -> Some (string_of_bool b)
  | `Null | `List _ -> None

let json_value (v : value) =
  match v with
  | `List items ->
      let items =
        take max_items
          (List.filter (function `Null -> false | _ -> true) items)
      in
      Some ("[" ^ String.concat "," (List.filter_map json_scalar items) ^ "]")
  | v -> json_scalar v

let page_props_json props =
  let fields =
    List.filter_map
      (fun (key, v) ->
        Option.map (fun j -> json_string key ^ ":" ^ j) (json_value v))
      (normalize props)
  in
  if fields = [] then None else Some ("{" ^ String.concat "," fields ^ "}")

(* Settings *)

module Config = struct
  type t = {
    site_id : string option;
    script_host : string option;
    modules : string list option;
    excluded_paths : string list;
    domains : string list;
    spa : spa;
    manual : bool;
    enabled : bool option;
    auto_inject : bool;
    extra_attributes : (string * string) list;
    props : props;
    queue_stub : bool;
  }

  let default =
    {
      site_id = None;
      script_host = None;
      modules = None;
      excluded_paths = [];
      domains = [];
      spa = `Auto;
      manual = false;
      enabled = None;
      auto_inject = false;
      extra_attributes = [];
      props = [];
      queue_stub = false;
    }

  let make ?site_id ?script_host ?modules ?(excluded_paths = []) ?(domains = [])
      ?(spa = `Auto) ?(manual = false) ?enabled ?(auto_inject = false)
      ?(extra_attributes = []) ?(props = []) ?(queue_stub = false) () =
    {
      site_id;
      script_host;
      modules;
      excluded_paths;
      domains;
      spa;
      manual;
      enabled;
      auto_inject;
      extra_attributes;
      props;
      queue_stub;
    }

  let env name =
    match Sys.getenv_opt name with
    | Some v when String.trim v <> "" -> Some (String.trim v)
    | _ -> None

  let site_id t =
    match Option.map String.trim t.site_id with
    | Some v when v <> "" -> Some v
    | _ -> env "PRIVATUS_SITE_ID"

  let script_host t =
    let host =
      match Option.map String.trim t.script_host with
      | Some v when v <> "" -> v
      | _ -> (
          match env "PRIVATUS_SCRIPT_HOST" with
          | Some v -> v
          | None -> default_host)
    in
    let n = String.length host in
    if n > 0 && host.[n - 1] = '/' then String.sub host 0 (n - 1) else host

  let enabled t =
    match t.enabled with
    | Some b -> b
    | None -> Sys.getenv_opt "PRIVATUS_ENV" = Some "production"

  let renders t = site_id t <> None && enabled t
end

(* The script tag *)

let list values =
  values
  |> List.concat_map (String.split_on_char ',')
  |> List.map String.trim
  |> List.filter (fun s -> s <> "")

let valid_attribute_name name =
  name <> ""
  && String.for_all
       (function
         | 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_' | '.' | ':' | '-' -> true
         | _ -> false)
       name

let spa_name : spa -> string option = function
  | `Auto -> None
  | `History -> Some "history"
  | `Hash -> Some "hash"
  | `Off -> Some "off"

let keyed props = List.map (fun (k, v) -> (normalize_key k, v)) props
let merge base over = List.fold_left (fun acc (k, v) -> set k v acc) base over

let override (config : Config.t) ?site_id ?script_host ?modules ?excluded_paths
    ?domains ?spa ?manual ?enabled ?extra_attributes ?queue_stub () =
  let pick o d = match o with Some v -> v | None -> d in
  {
    config with
    site_id = (match site_id with Some _ -> site_id | None -> config.site_id);
    script_host =
      (match script_host with
      | Some _ -> script_host
      | None -> config.script_host);
    modules = (match modules with Some _ -> modules | None -> config.modules);
    excluded_paths = pick excluded_paths config.excluded_paths;
    domains = pick domains config.domains;
    spa = pick spa config.spa;
    manual = pick manual config.manual;
    enabled = (match enabled with Some _ -> enabled | None -> config.enabled);
    extra_attributes = pick extra_attributes config.extra_attributes;
    queue_stub = pick queue_stub config.queue_stub;
  }

let inline_script ?nonce code =
  match nonce with
  | Some n when n <> "" ->
      Printf.sprintf "<script nonce=\"%s\">%s</script>" (escape_html n) code
  | _ -> "<script>" ^ code ^ "</script>"

let queue_stub_script ?nonce () = inline_script ?nonce queue_stub

let attributes ?nonce (config : Config.t) =
  let site = Option.value (Config.site_id config) ~default:"" in
  let attrs =
    [ ("src", Config.script_host config ^ marker); ("data-site", site) ]
    @ (match config.modules with
      | Some m -> [ ("data-modules", String.concat "," (list m)) ]
      | None -> [])
    @ (match list config.excluded_paths with
      | [] -> []
      | l -> [ ("data-exclude", String.concat "," l) ])
    @ (match list config.domains with
      | [] -> []
      | l -> [ ("data-domains", String.concat "," l) ])
    @ (match spa_name config.spa with
      | Some s -> [ ("data-spa", s) ]
      | None -> [])
    @ if config.manual then [ ("data-manual", "true") ] else []
  in
  let attrs =
    List.fold_left
      (fun acc (name, v) ->
        if valid_attribute_name name then set name v acc else acc)
      attrs config.extra_attributes
  in
  match nonce with Some n when n <> "" -> set "nonce" n attrs | _ -> attrs

let render ?nonce ?props_fn ?(props = []) (config : Config.t) =
  (* When the tag is off, only the queue stub prints (when it is on), so
     privatus.track calls never fail. props_fn is not called. *)
  if not (Config.renders config) then
    if config.queue_stub then queue_stub_script ?nonce () else ""
  else
    let base = keyed config.props in
    let base =
      match props_fn with Some f -> merge base (keyed (f ())) | None -> base
    in
    let json = page_props_json (merge base (keyed props)) in
    let attrs = attributes ?nonce config in
    let attrs =
      match json with
      | Some _ -> attrs @ [ ("data-props", props_function) ]
      | None -> attrs
    in
    let tracker = "<script defer " ^ attrs_to_html attrs ^ "></script>" in
    let parts =
      (if config.queue_stub then [ queue_stub_script ?nonce () ] else [])
      @ (match json with
        | Some j ->
            [
              inline_script ?nonce
                ("window." ^ props_function ^ "=function(){return " ^ j ^ "}");
            ]
        | None -> [])
      @ [ tracker ]
    in
    String.concat "\n" parts

let tag ?(config = Config.default) ?site_id ?script_host ?modules
    ?excluded_paths ?domains ?spa ?manual ?enabled ?extra_attributes ?queue_stub
    ?props ?props_fn ?nonce () =
  let config =
    override config ?site_id ?script_host ?modules ?excluded_paths ?domains ?spa
      ?manual ?enabled ?extra_attributes ?queue_stub ()
  in
  render ?nonce ?props_fn ?props config

(* Adding the tag to a page *)

let find sub s =
  let n = String.length sub and m = String.length s in
  let rec go i =
    if i + n > m then None
    else if String.sub s i n = sub then Some i
    else go (i + 1)
  in
  go 0

let contains s sub = find sub s <> None

let inject_html ~tag html =
  if tag = "" || contains html marker then None
  else
    match find "</head>" (String.lowercase_ascii html) with
    | None -> None
    | Some i ->
        Some
          (String.sub html 0 i ^ tag ^ "\n"
          ^ String.sub html i (String.length html - i))
