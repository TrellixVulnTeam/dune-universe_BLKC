module B = Decompress_b

type read  = [ `Read ]
type write = [ `Write ]

type ('a, 'i) t = 'i B.t constraint 'a = [< `Read | `Write ]

external read_and_write : 'i B.t -> ([ read | write ], 'i) t = "%identity"
external read_only      : 'i B.t -> (read, 'i) t             = "%identity"
external write_only     : 'i B.t -> (write, 'i) t            = "%identity"

let length    = B.length
let get       = B.get
let set       = B.set
let get_u16   = B.get_u16
let get_u32   = B.get_u32
let get_u64   = B.get_u64
let sub_ro    = B.sub
let sub_rw    = B.sub
let fill      = B.fill
let blit      = B.blit
let blit2     = B.blit2
let pp        = B.pp
let to_string = B.to_string
let adler32
    : type a. a B.t -> Checkseum.Adler32.t -> int -> int -> Checkseum.Adler32.t
  = fun v t off len -> match v with
  | B.Bytes v -> Checkseum.Adler32.digest_bytes v off len t
  | B.Bigstring v -> Checkseum.Adler32.digest_bigstring v off len t

external from : ('a, 'i) t -> 'i B.t = "%identity"