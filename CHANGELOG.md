# Changelog

## Unreleased

- Changed: with `queue_stub` on, a tag that is off (outside production, `~enabled:false` or no site id) now
  prints the queue stub and nothing else, so `privatus.track(...)` calls in your own JavaScript never fail.
  Before, it printed nothing. With the stub off it still prints nothing. `props_fn` and the middleware's props
  function still do not run when the tag is off.
- Added `example/`, a small Dream app for the conformance tests.
- README: a privacy policy paragraph you can paste.

## 1.0.0 (2026-10-25)

- Initial release of `privatus-analytics` and `privatus-analytics-dream`.
- `Privatus_analytics.tag` prints the tracking script, with settings for site
  id, script host, modules, excluded paths, domains, single page app mode,
  manual mode, extra attributes and a Content Security Policy nonce.
- The tag prints only when `PRIVATUS_ENV` is `production`, unless `enabled`
  forces it on or off.
- `event_attrs` and `event_data` for custom events on buttons, links and forms.
- `click_attr` and `click_data` for click map names.
- Page props (`props`), printed as the `privatusPageProps` script with
  `data-props`, and the `queue_stub` setting.
- `Privatus_analytics_dream.middleware`: keeps your settings for the `.eml`
  helpers, takes a props function that gets the request, and can add the tag
  to the head of HTML pages (`auto_inject`, off by default).
- `privatus-analytics.tyxml`: TyXML helpers, installed when TyXML is there.
