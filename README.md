# Privatus Analytics for OCaml

Adds the cookieless [Privatus Analytics](https://privatusanalytics.com)
tracking script to your OCaml web app. There are two opam packages:

* `privatus-analytics` builds the script tag and the HTML attributes. It
  needs nothing but OCaml. If you have TyXML, it also gives you
  `privatus-analytics.tyxml`.
* `privatus-analytics-dream` is for [Dream](https://aantron.github.io/dream/).
  It has a middleware that can put the tag in the `<head>` for you, and
  helpers for `.eml` templates.

Privatus Analytics counts visits, sources, pages and conversions without
cookies, local storage or fingerprinting, so analytics does not need a consent
banner by itself. Check with your own counsel for your country.

The packages only print the browser script. They never send events from your
server and set no cookies. You need a Privatus Analytics account to see
reports, and there is a free plan. Sign up at https://privatusanalytics.com.

## Requirements

* OCaml 4.14 or later (OCaml 5 works too) and dune.
* Dream 1.0.0~alpha5 or later, if you use the Dream package.
* A Privatus Analytics site id (it starts with `pa_`). You find it under
  Site settings, Tracking.

## Install

```sh
opam install privatus-analytics-dream   # for Dream apps
opam install privatus-analytics         # anything else
```

Then add the library to your `dune` file:

```lisp
(executable
 (name app)
 (libraries dream privatus-analytics privatus-analytics-dream))
```

For the full setup guide and every tracker option, see the [Privatus
Analytics docs](https://privatusanalytics.com/docs).

Set your site id with an environment variable:

```sh
PRIVATUS_SITE_ID=pa_YOURSITEID
```

or in your code:

```ocaml
let config = Privatus_analytics.Config.make ~site_id:"pa_YOURSITEID" ()
```

## Add the tag

With Dream, add the middleware once. It keeps your settings for the
template helpers:

```ocaml
let () =
  Dream.run
  @@ Dream.logger
  @@ Privatus_analytics_dream.middleware ~config
  @@ Dream.router [ Dream.get "/" (fun request -> Dream.html (Page.home request)) ]
```

Then put the helper in the `<head>` of your `.eml` template. Use `<%s! ... %>`
so Dream does not escape the HTML a second time. The helpers escape every
value already.

```html
let home request =
  <html>
  <head>
    <title>My app</title>
    <%s! Privatus_analytics_dream.tag request %>
  </head>
  ...
```

In production it prints:

```html
<script defer src="https://privatusstats.com/js/pa.js" data-site="pa_YOURSITEID"></script>
```

Without Dream, call the core library and put the text in your page:

```ocaml
let head = Privatus_analytics.tag ~config ()
```

With TyXML, `Privatus_analytics_tyxml.tag ~config ()` gives an element for
`Tyxml.Html.head`.

The tag prints nothing when there is no site id, and nothing outside
production (see below). If your app uses a Content Security Policy nonce, pass
it with `~nonce`, or give the middleware a function:
`Privatus_analytics_dream.middleware ~config ~nonce:(fun request -> ...)`.

### Or let the middleware add it

If you would rather not touch your templates, switch on `auto_inject`:

```ocaml
let config = Privatus_analytics.Config.make ~site_id:"pa_YOURSITEID" ~auto_inject:true ()
```

The middleware then adds the tag just before `</head>` in uncompressed
`text/html` responses with status 200. It skips Ajax requests, pages without
a `<head>`, and pages that already have the tag. Responses that carry a
`Content-Encoding` header are left alone, so if you compress pages in your
app, use the helper instead. When the response has a `Content-Length` header,
the middleware updates it.

## Configuration

Every setting is optional except the site id.

```ocaml
let config =
  Privatus_analytics.Config.make
    ~site_id:"pa_YOURSITEID"                  (* or PRIVATUS_SITE_ID *)
    ~script_host:"https://privatusstats.com"  (* or PRIVATUS_SCRIPT_HOST *)
    ~modules:[ "engage"; "auto"; "vitals"; "clicks"; "ask" ]
    ~excluded_paths:[ "/admin/*"; "/preview/*" ]
    ~domains:[ "example.com"; "www.example.com" ]
    ~spa:`Auto                                (* `Auto, `History, `Hash or `Off *)
    ~manual:false                             (* true turns off the automatic pageview *)
    ~auto_inject:false
    ~extra_attributes:[ ("data-mask", "/orders/*->/orders/:id") ]
    ~props:[ ("app_version", `String "2.4") ]
    ~queue_stub:false
    ()
```

`Config.t` is a plain record, so `{ config with manual = true }` works too.

| Setting | Default | What it does |
|---|---|---|
| `site_id` | `PRIVATUS_SITE_ID` | The `data-site` attribute. Nothing prints without it |
| `script_host` | `https://privatusstats.com` | Where `/js/pa.js` is served. Change it only if you host your own copy. Falls back to `PRIVATUS_SCRIPT_HOST` |
| `modules` | tracker default (`engage`) | The `data-modules` attribute. Setting it replaces the default, so keep `engage` for time on page and scroll depth. `[]` loads none |
| `excluded_paths` | none | The `data-exclude` attribute. Path patterns the tracker never counts |
| `domains` | all hosts | The `data-domains` attribute. Count only these hostnames |
| `spa` | `` `Auto `` | The `data-spa` attribute (single page app mode) |
| `manual` | `false` | The `data-manual` attribute |
| `enabled` | not set | `true` or `false` forces the tag on or off. When not set, the tag is on only when `PRIVATUS_ENV=production` |
| `auto_inject` | `false` | Lets the Dream middleware add the tag |
| `extra_attributes` | `[]` | Any other `data-*` attribute |
| `props` | `[]` | Page props sent with every pageview and event. See below |
| `queue_stub` | `false` | Prints a small script first, so `privatus.track` calls made before the tracker loads are kept and sent later |

Each tracker attribute is explained in the [script attributes
reference](https://privatusanalytics.com/docs/tracker/attributes), and the
modules in [Modules](https://privatusanalytics.com/docs/tracker/modules).

You can also override a setting for one page:

```html
<%s! Privatus_analytics_dream.tag request ~modules:[ "engage"; "auto" ] ~excluded_paths:[ "/preview/*" ] %>
```

### Development and test

The tag prints only when the `PRIVATUS_ENV` environment variable is
`production`, so your own clicking around never reaches your reports. Set
`PRIVATUS_ENV=production` on your live server. To see the tag while you
build, use `~enabled:true`. The tracker also ignores `localhost` unless you
pass `data-allow-local` or `data-debug` (see [Debug
mode](https://privatusanalytics.com/docs/tracker/debug)):

```ocaml
~extra_attributes:[ ("data-debug", "true") ]
```

### Leaving people out

Use `excluded_paths` (the `data-exclude` attribute) for admin areas. To leave
out signed-in staff, print the tag only for other people:

```html
<%s! if is_staff request then "" else Privatus_analytics_dream.tag request %>
```

## Product analytics: see which features people use

Privatus can show which buttons, forms and features people really use. You
add a few attributes to your HTML. The tracker reads them in the browser and
sends the events. Your server still sends nothing.

### Name events well

Use a short "Noun verb" name, like `Report exported` or `Invite sent`. Put the
details in props, not in the name. So write `Report exported` with
`format = csv`, not `Report exported as CSV`. Then all exports add up in one
place, and you can split them by format.

### Events on buttons, links and forms

`event_attrs` prints the attributes inside a tag you write yourself:

```html
<button <%s! Privatus_analytics_dream.event_attrs "Report exported"
               ~props:[ ("format", `String "csv"); ("source", `String "toolbar") ] %>>Export</button>
```

It prints:

```html
<button data-privatus-event="Report exported" data-privatus-prop-format="csv" data-privatus-prop-source="toolbar">Export</button>
```

On a form, the event is sent when the form is submitted:

```html
<form method="post" action="/newsletter" <%s! Privatus_analytics_dream.event_attrs "Newsletter joined" ~props:[ ("list", `String "weekly") ] %>>
```

Without Dream, call `Privatus_analytics.event_attrs`. For HTML builders,
`Privatus_analytics.event_data` gives the attributes as name and value pairs,
and with TyXML use `Privatus_analytics_tyxml.event`:

```ocaml
Tyxml.Html.button
  ~a:(Privatus_analytics_tyxml.event "Report exported" ~props:[ ("format", `String "csv") ])
  [ Tyxml.Html.txt "Export" ]
```

Prop values are `` `String ``, `` `Int ``, `` `Float ``, `` `Bool ``,
`` `List `` and `` `Null ``. The rules:

* The name is trimmed and cut to 120 characters. An empty name prints nothing.
* Prop keys are made lowercase. Anything that is not a letter, a digit or `_`
  becomes `_`, so `"Report Type"` becomes `report_type`. Keys are cut to 64
  characters.
* At most 30 props. Values become text: `true`, `false`, numbers as written,
  lists joined with commas. `` `Null `` values are left out. Values are cut to
  500 characters.
* Everything is escaped for HTML.
* The attributes print in every environment, even when the tag is off. They do
  nothing without the tracker, so your pages look the same in development and
  production.

### Click maps

A click map shows where people click on a page. Give the important parts a
name so they stay easy to find, even when the page changes:

```html
<a href="/pricing" <%s! Privatus_analytics_dream.click_attr "pricing.cta" %>>See plans</a>
```

It prints `data-privatus-click="pricing.cta"`. A name may use letters, digits
and `_ . : -`, up to 100 characters. Anything else prints nothing, and outside
production the Dream helper writes a warning to the Dream log. The core
library has `Privatus_analytics.click_attr` and `click_data`, and TyXML users
have `Privatus_analytics_tyxml.click`.

### Page props: plan, role and other groups

Page props are sent with every pageview and event on the page. Use them to
split your reports by plan, role, app version, feature flag or account tier.

With Dream, give the middleware a function. It runs on each request where the
tag prints, after your handler, and gets the request:

```ocaml
let props request =
  [ ("plan", match plan_of request with Some p -> `String p | None -> `Null);
    ("role", `String (role_of request));
    ("app_version", `String "2.4") ]

let () =
  Dream.run
  @@ Privatus_analytics_dream.middleware ~config ~props
  @@ router
```

Props set in `Config.make ~props` work too. You can also set or change props
for one page. They are merged over the configured ones, and `` `Null ``
removes one:

```html
<%s! Privatus_analytics_dream.tag request ~props:[ ("section", `String "billing"); ("role", `Null) ] %>
```

The tag then prints a small script before the tracker, with your Content
Security Policy nonce when you have one, and points the tracker at it:

```html
<script nonce="...">window.privatusPageProps=function(){return {"plan":"pro","role":"admin"}}</script>
<script defer src="https://privatusstats.com/js/pa.js" data-site="pa_YOURSITEID" data-props="privatusPageProps"></script>
```

Keys follow the same rules as event props. Numbers and true or false stay as
they are, and lists stay lists (up to 30 items). The props are escaped so they
are safe inside a script. The middleware uses the same function when
`auto_inject` is on.

**Never put names, emails, user ids or anything that points to one person in
props.** Privatus counts visitors without any id. Put groups (like the plan or
the role), not people. The server also removes emails and long ids it finds.

### Track from your own JavaScript

For things that are not a click or a submit, call the tracker from your
JavaScript, as the [JavaScript API
docs](https://privatusanalytics.com/docs/tracker/javascript-api) explain:

```js
privatus.track("Feature used", { feature: "export" })
```

If your code may run before the tracker has loaded, switch on the queue stub.
It prints a tiny script before the tracker that keeps your calls in a list and
sends them once the tracker is ready:

```ocaml
let config = Privatus_analytics.Config.make ~site_id:"pa_YOURSITEID" ~queue_stub:true ()
```

or for one page: `<%s! Privatus_analytics_dream.tag request ~queue_stub:true %>`.
Like the tag, the stub prints only where the tag is on, so in development use
`window.privatus && privatus.track(...)`.

### See the results

* [Funnels](https://privatusanalytics.com/docs/features/funnels): how many
  people go from one step to the next.
* [Click maps](https://privatusanalytics.com/docs/features/click-maps): where
  people click.
* [Goals](https://privatusanalytics.com/docs/features/goals): turn an event
  into a goal to count conversions.
* [Events](https://privatusanalytics.com/docs/events): every custom event and
  its props.

## Privacy

The script sets no cookies and stores nothing in the browser. The event, click
and props helpers only print HTML attributes and a small script. These
packages make no web requests and never read IP addresses or browser details.
Keep people out of your props and event props: no names, emails or user ids.
See the [privacy documentation](https://privatusanalytics.com/docs/privacy)
for what is collected.

## Development

The checks run in Docker so your local OCaml does not matter:

```sh
./run-docker.sh
```

It uses the official `ocaml/opam:debian-ocaml-5.2` image and keeps installed
opam packages in a Docker volume named `privatus-ocaml-opam`. It builds both
packages, checks the formatting with ocamlformat, runs the Alcotest suites
(including a real Dream `.eml` template), builds the odoc docs, and runs
`opam lint`. The `.opam` files are made by dune from `dune-project`, so edit
that file instead.

## Contributing

Bug reports and pull requests are welcome at
https://github.com/Privatus-Analytics/ocaml.

## License

MIT. See [LICENSE](LICENSE). Privatus Analytics is a product of Two Phase LLC,
Wyoming, USA.
