open Js_of_ocaml

let response_ctor : 'a Js.t =
  Js.Unsafe.get Js.Unsafe.global (Js.string "Response")

let js_get obj key =
  let v : Js.js_string Js.t Js.optdef = Js.Unsafe.get obj (Js.string key) in
  Js.Optdef.get v (fun () -> Js.string "") |> Js.to_string

let fetch request env =
  let url     = js_get request "url" in
  let method_ = Worker_types.method_of_string (js_get request "method") in
  let req     = Worker_types.{ url; method_; headers = [] } in
  let resp    = Worker_handler.handle req in
  let sha     = js_get env "COMMIT_SHA" in
  let body    = resp.Worker_types.body ^ " from js_of_ocaml (commit: " ^ sha ^ ")" in
  Js.Unsafe.new_obj response_ctor
    [| Js.Unsafe.inject (Js.string body) |]

let step_parse_js url method_ =
  let (_, norm) = Worker_workflow.step_parse
    (Js.to_string url) (Js.to_string method_) in
  Js.string norm

let step_greet_js url method_ =
  Js.string (Worker_workflow.step_greet
    (Js.to_string url) (Js.to_string method_))

let step_annotate_js body sha =
  Js.string (Worker_workflow.step_annotate
    (Js.to_string body) "js_of_ocaml" (Js.to_string sha))

let () =
  Js.Unsafe.set Js.Unsafe.global
    (Js.string "ocamlWorkerFetch")
    (Js.Unsafe.callback fetch);
  Js.Unsafe.set Js.Unsafe.global
    (Js.string "ocamlStepParse")
    (Js.Unsafe.callback step_parse_js);
  Js.Unsafe.set Js.Unsafe.global
    (Js.string "ocamlStepGreet")
    (Js.Unsafe.callback step_greet_js);
  Js.Unsafe.set Js.Unsafe.global
    (Js.string "ocamlStepAnnotate")
    (Js.Unsafe.callback step_annotate_js)
