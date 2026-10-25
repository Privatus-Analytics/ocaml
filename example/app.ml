(* Conformance example app for privatus-analytics-dream.

   Built by the conformance suite
   (https://github.com/Privatus-Analytics/conformance). See its CONTRACT.md
   for what each route must render. The site id and script host come from
   PRIVATUS_SITE_ID and PRIVATUS_SCRIPT_HOST. *)

let nonce = "testnonce"

(* Forced on, so the tag prints whatever the environment. *)
let config = Privatus_analytics.Config.make ~enabled:true ()

let csp inner request =
  Lwt.bind (inner request) (fun response ->
      Dream.set_header response "Content-Security-Policy"
        (Printf.sprintf "script-src 'nonce-%s' %s" nonce
           (Privatus_analytics.Config.script_host config));
      Lwt.return response)

let with_privatus ?(auto_inject = false) () =
  Privatus_analytics_dream.middleware ~config:{ config with auto_inject }
    ~nonce:(fun _ -> Some nonce)

let page render request = Dream.html (render request)

let () =
  let port =
    Option.value ~default:8080
      (Option.bind (Sys.getenv_opt "PORT") int_of_string_opt)
  in
  Dream.run ~interface:"0.0.0.0" ~port
  @@ Dream.logger @@ csp
  @@ Dream.router
       [
         Dream.scope "/"
           [ with_privatus () ]
           [
             Dream.get "/" (page Pages.home);
             Dream.get "/event" (page Pages.event);
             Dream.get "/nasty" (page Pages.nasty_page);
             Dream.get "/off" (page (Pages.off ~queue_stub:true));
             Dream.get "/off-plain" (page (Pages.off ~queue_stub:false));
           ];
         (* Auto inject on this route only, so the other routes test the
            template helper alone. *)
         Dream.scope "/"
           [ with_privatus ~auto_inject:true () ]
           [ Dream.get "/auto" (page Pages.auto) ];
       ]
