;; extends

; Inject the *result* language into bare text nodes of a Go template.
; Language is chosen at runtime by #inject-gotmpl-host! (see lua/bsi/gotmpl.lua):
;   1. double extension: page.html.tmpl, config.yaml.tmpl
;   2. content heuristics: HTML tags, YAML keys, JSON braces, etc.
((text) @injection.content
  (#inject-gotmpl-host!)
  (#set! injection.combined))
