(** TyXML helpers for Privatus Analytics.

    {[
    let open Tyxml.Html in
    button
      ~a:
        (Privatus_analytics_tyxml.event
           ~props:[ ("format", `String "csv") ]
           "Report exported")
      [ txt "Export" ]
    ]}

    This library is installed only when [tyxml] is installed. *)

val event :
  ?props:Privatus_analytics.props ->
  string ->
  [> `User_data ] Tyxml.Html.attrib list
(** The custom event attributes, following the rules of
    {!Privatus_analytics.event_attrs}. [[]] for an empty name. *)

val click : string -> [> `User_data ] Tyxml.Html.attrib list
(** The click map name attribute, or [[]] when the name is not valid. *)

val tag :
  ?config:Privatus_analytics.Config.t ->
  ?queue_stub:bool ->
  ?props:Privatus_analytics.props ->
  ?nonce:string ->
  unit ->
  [> Html_types.script ] Tyxml.Html.elt
(** The script tag from {!Privatus_analytics.tag}, as raw HTML for the [head].
    It is empty when the tag is off. *)
