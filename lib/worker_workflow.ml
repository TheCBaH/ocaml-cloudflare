(* Three Workflow steps — pure OCaml, no JS FFI.
   All inputs and outputs are plain strings so CF Workflow can serialise them
   durably between steps. *)

(* Step 1: parse and normalise the HTTP method via the method_ ADT.
   Returns (url, normalised_method). *)
let step_parse url method_str =
  let norm = Worker_types.(method_to_string (method_of_string method_str)) in
  (url, norm)

(* Step 2: produce the greeting body. *)
let step_greet url method_str =
  let req = Worker_types.{
    url; method_ = method_of_string method_str; headers = [] } in
  (Worker_handler.handle req).Worker_types.body

(* Step 3: append backend name and commit SHA. *)
let step_annotate body backend commit =
  Printf.sprintf "%s from %s (commit: %s)" body backend commit
