let nasty = "</script><script>window.__pwned=1</script>\xe2\x80\xa8\xe2\x80\xa9&<>\"'"

let page_props =
  [ ("plan", `String "pro"); ("role", `String "admin"); ("beta", `Bool true); ("seats", `Int 3) ]

let home request =
  <!doctype html>
  <html lang="en">
  <head>
  <meta charset="utf-8">
  <title>Home</title>
  <%s! Privatus_analytics_dream.tag request ~props:page_props ~queue_stub:true %>
  </head>
  <body><h1>Home</h1></body>
  </html>

let event request =
  <!doctype html>
  <html lang="en">
  <head>
  <meta charset="utf-8">
  <title>Events</title>
  <%s! Privatus_analytics_dream.tag request ~props:page_props ~queue_stub:true %>
  </head>
  <body>
  <h1>Events</h1>
  <button type="button" <%s! Privatus_analytics_dream.event_attrs "Report exported" ~props:[ ("format", `String "csv"); ("source", `String "toolbar") ] %>>Export report</button>
  <p><a href="#pricing" <%s! Privatus_analytics_dream.click_attr "pricing.cta" %>>Pricing</a></p>
  <form action="/event" method="get" <%s! Privatus_analytics_dream.event_attrs "Signup form" %>>
    <button type="submit">Sign up</button>
  </form>
  </body>
  </html>

let nasty_page request =
  <!doctype html>
  <html lang="en">
  <head>
  <meta charset="utf-8">
  <title>Nasty</title>
  <%s! Privatus_analytics_dream.tag request ~props:(page_props @ [ ("nasty", `String nasty) ]) ~queue_stub:true %>
  </head>
  <body>
  <h1>Nasty values</h1>
  <button type="button" <%s! Privatus_analytics_dream.event_attrs "Nasty value" ~props:[ ("nasty", `String nasty) ] %>>Nasty</button>
  </body>
  </html>

(* Off with the queue stub on prints only the stub, so privatus.track still
   works. Off with the stub off prints nothing. *)
let off request ~queue_stub =
  <!doctype html>
  <html lang="en">
  <head>
  <meta charset="utf-8">
  <title>Off</title>
  <meta name="privatus-off-start"><%s! Privatus_analytics_dream.tag request ~enabled:false ~props:page_props ~queue_stub %><meta name="privatus-off-end">
  </head>
  <body><h1>Off</h1></body>
  </html>

let auto _request =
  <!doctype html>
  <html lang="en">
  <head>
  <meta charset="utf-8">
  <title>Auto inject</title>
  </head>
  <body><h1>Auto inject</h1><p>No tag in the template. The middleware adds it.</p></body>
  </html>
