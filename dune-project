(lang dune 3.0)

(name privatus-analytics)

(version 1.0.0)

(generate_opam_files true)

(source
 (github Privatus-Analytics/ocaml))

(homepage "https://privatusanalytics.com")

(bug_reports "https://github.com/Privatus-Analytics/ocaml/issues")

(documentation "https://privatusanalytics.com/docs")

(license MIT)

(authors "Two Phase LLC <james@privatusanalytics.com>")

(maintainers "Two Phase LLC <james@privatusanalytics.com>")

(package
 (name privatus-analytics)
 (synopsis "Cookieless Privatus Analytics tracking script for OCaml web apps")
 (description
  "Prints the Privatus Analytics browser script tag, page props and the data attributes for custom events and click maps. It only builds HTML. It never sends events from your server and sets no cookies. The optional privatus-analytics.tyxml library adds TyXML attribute helpers.")
 (tags
  (analytics privacy web html))
 (depends
  (ocaml
   (>= 4.14))
  (alcotest
   (and
    :with-test
    (>= 1.5)))
  (odoc :with-doc))
 (depopts tyxml)
 (conflicts
  (tyxml
   (< 4.5))))

(package
 (name privatus-analytics-dream)
 (synopsis "Privatus Analytics tracking script for Dream web apps")
 (description
  "A Dream middleware that can add the cookieless Privatus Analytics script to the head of HTML pages, and helpers for Dream .eml templates: the script tag, custom event attributes, click map names and page props from the request. It never sends events from your server and sets no cookies.")
 (tags
  (analytics privacy web dream))
 (depends
  (ocaml
   (>= 4.14))
  (privatus-analytics
   (= :version))
  (dream
   (>= 1.0.0~alpha5))
  (lwt
   (>= 5.3.0))
  (alcotest
   (and
    :with-test
    (>= 1.5)))
  (odoc :with-doc)))
