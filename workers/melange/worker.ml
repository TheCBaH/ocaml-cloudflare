type response

external make_response  : string -> response = "Response"   [@@mel.new]
external get_commit_sha : 'a -> string       = "COMMIT_SHA" [@@mel.get]
external get_url        : 'a -> string option = "url"    [@@mel.get] [@@mel.return nullable]
external get_method     : 'a -> string option = "method" [@@mel.get] [@@mel.return nullable]

let fetch (request : 'a) (env : 'b) (_ctx : 'c) : response =
  let url     = get_url request |> Option.value ~default:"" in
  let method_ = Worker_types.method_of_string
                  (get_method request |> Option.value ~default:"GET") in
  let req     = Worker_types.{ url; method_; headers = [] } in
  let resp    = Worker_handler.handle req in
  let sha     = get_commit_sha env in
  let body    = resp.Worker_types.body ^ " from melange (commit: " ^ sha ^ ")" in
  make_response body
