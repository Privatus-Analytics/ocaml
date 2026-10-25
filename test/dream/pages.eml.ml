let layout request =
  <html>
  <head>
    <title>Home</title>
    <%s! Privatus_analytics_dream.tag request %>
  </head>
  <body><p>Hello</p></body>
  </html>

let features _request =
  <html>
  <head><title>Features</title></head>
  <body>
    <button <%s! Privatus_analytics_dream.event_attrs "Export CSV" ~props:[ ("format", `String "csv") ] %>>Export</button>
    <a <%s! Privatus_analytics_dream.click_attr "pricing.cta" %> href="/pricing">Pricing</a>
  </body>
  </html>
