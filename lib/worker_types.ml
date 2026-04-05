type method_ = GET | POST | PUT | DELETE | Other of string

type request = {
  url     : string;
  method_ : method_;
  headers : (string * string) list;
}

type response = {
  status : int;
  body   : string;
}

let method_to_string = function
  | GET       -> "GET"
  | POST      -> "POST"
  | PUT       -> "PUT"
  | DELETE    -> "DELETE"
  | Other m   -> m

let method_of_string = function
  | "GET"    -> GET
  | "POST"   -> POST
  | "PUT"    -> PUT
  | "DELETE" -> DELETE
  | other    -> Other other

let pp_method fmt m =
  Format.pp_print_string fmt (method_to_string m)

let pp_request fmt r =
  Format.fprintf fmt "Request { method = %a; url = %S; headers = [%a] }"
    pp_method r.method_
    r.url
    (Format.pp_print_list
       ~pp_sep:(fun fmt () -> Format.pp_print_string fmt "; ")
       (fun fmt (k, v) -> Format.fprintf fmt "%S: %S" k v))
    r.headers

let pp_response fmt r =
  Format.fprintf fmt "Response { status = %d; body = %S }"
    r.status r.body
