open Js_of_ocaml

(* Access the CF Worker global Response constructor *)
let response_ctor : 'a Js.t =
  Js.Unsafe.get Js.Unsafe.global (Js.string "Response")

(* Read a string binding from the CF Worker env object.
   Returns "unknown" when the binding is absent (e.g. local dev). *)
let env_string env key =
  let v = Js.Unsafe.get env (Js.string key) in
  (* coerce to js_string Js.t; undefined becomes the literal "undefined" but
     that is fine for local dev — we only check the SHA in CI. *)
  Js.to_string (Js.Unsafe.coerce v)

(* The fetch handler receives (request, env) from the ESM suffix.
   It returns a plain-text Response that embeds the commit SHA so the
   post-deploy integration test can verify the right version is live. *)
let fetch _request env =
  let sha = env_string env "COMMIT_SHA" in
  let body =
    "Hello, World from js_of_ocaml! (commit: " ^ sha ^ ")"
  in
  Js.Unsafe.new_obj response_ctor
    [| Js.Unsafe.inject (Js.string body) |]

(* Expose the handler as a global so the ESM suffix can re-export it *)
let () =
  Js.Unsafe.set Js.Unsafe.global
    (Js.string "ocamlWorkerFetch")
    (Js.Unsafe.callback fetch)
