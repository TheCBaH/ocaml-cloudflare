let handle (req : Worker_types.request) : Worker_types.response =
  let body =
    Printf.sprintf "Hello, World! [%s %s]"
      (Worker_types.method_to_string req.method_)
      req.url
  in
  { Worker_types.status = 200; body }
