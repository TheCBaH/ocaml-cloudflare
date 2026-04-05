let () =
  let req = Worker_types.{
    url     = "https://example.com/greet";
    method_ = GET;
    headers = [ ("accept", "text/plain") ];
  } in
  let resp = Worker_handler.handle req in
  Format.printf "Request:  %a@." Worker_types.pp_request req;
  Format.printf "Response: %a@." Worker_types.pp_response resp
