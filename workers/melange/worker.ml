type response

external make_response  : string -> response = "Response"   [@@mel.new]
external get_commit_sha : 'a -> string       = "COMMIT_SHA" [@@mel.get]
external get_url        : 'a -> string option = "url"    [@@mel.get] [@@mel.return nullable]
external get_method     : 'a -> string option = "method" [@@mel.get] [@@mel.return nullable]

(* Workflow step exports — called from entry.js OcamlWorkflow.run.
   Returns plain strings so CF can serialise step results durably. *)

let step_parse (_url : string) (method_ : string) : string =
  let (_, norm) = Worker_workflow.step_parse _url method_ in
  norm

let step_greet (url : string) (method_ : string) : string =
  Worker_workflow.step_greet url method_

let step_annotate (body : string) (sha : string) : string =
  Worker_workflow.step_annotate body "melange" sha

let fetch (request : 'a) (env : 'b) (_ctx : 'c) : response =
  let url     = get_url request |> Option.value ~default:"" in
  let method_ = Worker_types.method_of_string
                  (get_method request |> Option.value ~default:"GET") in
  let req     = Worker_types.{ url; method_; headers = [] } in
  let resp    = Worker_handler.handle req in
  let sha     = get_commit_sha env in
  let body    = resp.Worker_types.body ^ " from melange (commit: " ^ sha ^ ")" in
  make_response body
