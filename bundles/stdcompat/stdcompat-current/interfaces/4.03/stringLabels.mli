external length : string -> int = "%string_length"
external get : string -> int -> char = "%string_safe_get"
external set : bytes -> int -> char -> unit = "%string_safe_set"[@@ocaml.deprecated
                                                                  "Use BytesLabels.set instead."]
external create : int -> bytes = "caml_create_string"[@@ocaml.deprecated
                                                       "Use BytesLabels.create instead."]
val make : int -> char -> string
val init : int -> f:(int -> char) -> string
val copy : string -> string
val sub : string -> pos:int -> len:int -> string
val fill : bytes -> pos:int -> len:int -> char -> unit[@@ocaml.deprecated
                                                        "Use BytesLabels.fill instead."]
val blit :
  src:string -> src_pos:int -> dst:bytes -> dst_pos:int -> len:int -> unit
val concat : sep:string -> string list -> string
val iter : f:(char -> unit) -> string -> unit
val iteri : f:(int -> char -> unit) -> string -> unit
val map : f:(char -> char) -> string -> string
val mapi : f:(int -> char -> char) -> string -> string
val trim : string -> string
val escaped : string -> string
val index : string -> char -> int
val rindex : string -> char -> int
val index_from : string -> int -> char -> int
val rindex_from : string -> int -> char -> int
val contains : string -> char -> bool
val contains_from : string -> int -> char -> bool
val rcontains_from : string -> int -> char -> bool
val uppercase : string -> string
val lowercase : string -> string
val capitalize : string -> string
val uncapitalize : string -> string
type t = string
val compare : t -> t -> int
external unsafe_get : string -> int -> char = "%string_unsafe_get"
external unsafe_set : bytes -> int -> char -> unit = "%string_unsafe_set"
[@@ocaml.deprecated "- : bytes -> int -> char -> unit = <fun>"]
external unsafe_blit :
  src:string -> src_pos:int -> dst:bytes -> dst_pos:int -> len:int -> unit =
    "caml_blit_string"[@@noalloc ]
external unsafe_fill :
  bytes -> pos:int -> len:int -> char -> unit = "caml_fill_string"[@@ocaml.deprecated
                                                                    "- : bytes -> pos:int -> len:int -> char -> unit = <fun>"]
[@@noalloc ]
