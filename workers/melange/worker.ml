(* Cloudflare Worker "Hello World" compiled with melange.
   The COMMIT_SHA env binding is injected by wrangler at deploy time so the
   post-deploy integration test can verify the right version is live. *)

type response

external make_response : string -> response = "Response" [@@mel.new]

(* Read the COMMIT_SHA string binding from the CF Worker env object.
   Returns "unknown" when absent (e.g. local dev). *)
external get_commit_sha : 'a -> string = "COMMIT_SHA" [@@mel.get]

let fetch (_request : 'a) (env : 'b) (_ctx : 'c) : response =
  let sha = get_commit_sha env in
  make_response ("Hello, World from melange! (commit: " ^ sha ^ ")")
