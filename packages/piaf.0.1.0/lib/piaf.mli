(*----------------------------------------------------------------------------
 * Copyright (c) 2019-2020, António Nuno Monteiro
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its
 *    contributors may be used to endorse or promote products derived from
 *    this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *---------------------------------------------------------------------------*)

module IOVec : sig
  type 'a t = 'a Faraday.iovec =
    { buffer : 'a
    ; off : int
    ; len : int
    }

  val make : 'a -> off:int -> len:int -> 'a t

  val length : _ t -> int

  val lengthv : _ t list -> int

  val shift : 'a t -> int -> 'a t

  val shiftv : 'a t list -> int -> 'a t list

  val pp_hum : Format.formatter -> _ t -> unit [@@ocaml.toplevel_printer]
end

module Method : module type of Method

module Headers : sig
  (** The type of a group of header fields. *)
  type t

  (** The type of a lowercase header name. *)
  type name = string

  (** The type of a header value. *)
  type value = string

  (** {3 Constructor} *)

  val empty : t
  (** [empty] is the empty collection of header fields. *)

  val of_list : (name * value) list -> t
  (** [of_list assoc] is a collection of header fields defined by the
      association list [assoc]. [of_list] assumes the order of header fields in
      [assoc] is the intended transmission order. The following equations should
      hold:

      - [to_list (of_list lst) = lst]
      - [get (of_list \[("k", "v1"); ("k", "v2")\]) "k" = Some "v2"]. *)

  val of_rev_list : (name * value) list -> t
  (** [of_list assoc] is a collection of header fields defined by the
      association list [assoc]. [of_list] assumes the order of header fields in
      [assoc] is the {i reverse} of the intended trasmission order. The
      following equations should hold:

      - [to_list (of_rev_list lst) = List.rev lst]
      - [get (of_rev_list \[("k", "v1"); ("k", "v2")\]) "k" = Some "v1"]. *)

  val to_list : t -> (name * value) list
  (** [to_list t] is the association list of header fields contained in [t] in
      transmission order. *)

  val to_rev_list : t -> (name * value) list
  (** [to_rev_list t] is the association list of header fields contained in [t]
      in {i reverse} transmission order. *)

  val add : t -> ?sensitive:bool -> name -> value -> t
  (** [add t ?sensitive name value] is a collection of header fields that is the
      same as [t] except with [(name, value)] added at the end of the
      trasmission order. Additionally, [sensitive] specifies whether this header
      field should not be compressed by HPACK and instead encoded as a
      never-indexed literal (see
      {{:https://tools.ietf.org/html/rfc7541#section-7.1.3} RFC7541§7.1.3} for
      more details).

      The following equations should hold:

      - [get (add t name value) name = Some value] *)

  val add_unless_exists : t -> ?sensitive:bool -> name -> value -> t
  (** [add_unless_exists t ?sensitive name value] is a collection of header
      fields that is the same as [t] if [t] already inclues [name], and
      otherwise is equivalent to [add t ?sensitive name value]. *)

  val add_list : t -> (name * value) list -> t
  (** [add_list t assoc] is a collection of header fields that is the same as
      [t] except with all the header fields in [assoc] added to the end of the
      transmission order, in reverse order. *)

  val add_multi : t -> (name * value list) list -> t
  (** [add_multi t assoc] is the same as

      {[
        add_list
          t
          (List.concat_map assoc ~f:(fun (name, values) ->
               List.map values ~f:(fun value -> name, value)))
      ]}

      but is implemented more efficiently. For example,

      {[
        add_multi t [ "name1", [ "x", "y" ]; "name2", [ "p", "q" ] ]
        = add_list [ "name1", "x"; "name1", "y"; "name2", "p"; "name2", "q" ]
      ]} *)

  val remove : t -> name -> t
  (** [remove t name] is a collection of header fields that contains all the
      header fields of [t] except those that have a header-field name that are
      equal to [name]. If [t] contains multiple header fields whose name is
      [name], they will all be removed. *)

  val replace : t -> ?sensitive:bool -> name -> value -> t
  (** [replace t ?sensitive name value] is a collection of header fields that is
      the same as [t] except with all header fields with a name equal to [name]
      removed and replaced with a single header field whose name is [name] and
      whose value is [value]. This new header field will appear in the
      transmission order where the first occurrence of a header field with a
      name matching [name] was found.

      If no header field with a name equal to [name] is present in [t], then the
      result is simply [t], unchanged. *)

  (** {3 Destructors} *)

  val mem : t -> name -> bool
  (** [mem t name] is [true] iff [t] includes a header field with a name that is
      equal to [name]. *)

  val get : t -> name -> value option
  (** [get t name] returns the last header from [t] with name [name], or [None]
      if no such header is present. *)

  val get_exn : t -> name -> value
  (** [get t name] returns the last header from [t] with name [name], or raises
      if no such header is present. *)

  val get_multi : t -> name -> value list
  (** [get_multi t name] is the list of header values in [t] whose names are
      equal to [name]. The returned list is in transmission order. *)

  (** {3 Iteration} *)

  val iter : f:(name -> value -> unit) -> t -> unit

  val fold : f:(name -> value -> 'a -> 'a) -> init:'a -> t -> 'a

  (** {3 Utilities} *)

  val to_string : t -> string

  val pp_hum : Format.formatter -> t -> unit

  module Well_known : sig
    module HTTP1 : sig
      val host : string
    end

    module HTTP2 : sig
      val host : string
    end

    val authorization : string

    val connection : string

    val content_length : string

    val content_type : string

    val location : string

    val upgrade : string

    val transfer_encoding : string
  end
end

module Scheme : sig
  type t =
    | HTTP
    | HTTPS

  val of_uri : Uri.t -> (t, [ `Msg of string ]) result

  val to_string : t -> string

  val pp_hum : Format.formatter -> t -> unit [@@ocaml.toplevel_printer]
end

module Status : module type of Status

module Versions : sig
  module HTTP : sig
    include module type of struct
      include Httpaf.Version
    end

    val v1_0 : t

    val v1_1 : t

    val v2_0 : t
  end

  module TLS : sig
    type t =
      | Any
      | SSLv3
      | TLSv1_0
      | TLSv1_1
      | TLSv1_2
      | TLSv1_3

    val compare : t -> t -> int

    val of_string : string -> (t, string) result

    val pp_hum : Format.formatter -> t -> unit [@@ocaml.toplevel_printer]
  end

  module ALPN : sig
    type nonrec t =
      | HTTP_1_0
      | HTTP_1_1
      | HTTP_2

    val of_version : HTTP.t -> t option

    val to_version : t -> HTTP.t

    val of_string : string -> t option

    val to_string : t -> string
  end
end

module Config : sig
  type t =
    { follow_redirects : bool  (** whether to follow redirects *)
    ; max_redirects : int
          (** max redirects to follow. Could probably be rolled up into one
              option *)
    ; allow_insecure : bool
          (** Wether to allow insecure server connections when using SSL *)
    ; max_http_version : Versions.HTTP.t
          (** Use this as the highest HTTP version when sending requests *)
    ; h2c_upgrade : bool
          (** Send an upgrade to `h2c` (HTTP/2 over TCP) request to the server.
              `http2_prior_knowledge` below ignores this option. *)
    ; http2_prior_knowledge : bool
          (** Assume HTTP/2 prior knowledge -- don't use HTTP/1.1 Upgrade when
              communicating with "http" URIs, default to HTTP/2.0 when we can't
              agree to an ALPN protocol and communicating with "https" URIs. *)
    ; cacert : string option
          (** The path to a CA certificates file in PEM format *)
    ; capath : string option
          (** The path to a directory which contains CA certificates in PEM
              format *)
    ; min_tls_version : Versions.TLS.t
    ; max_tls_version : Versions.TLS.t
    ; tcp_nodelay : bool
    ; connect_timeout : float (* Buffer sizes *)
    ; buffer_size : int
          (** Buffer size used for requests and responses. Defaults to 16384
              bytes *)
    ; body_buffer_size : int
          (** Buffer size used for request and response bodies. *)
    ; enable_http2_server_push : bool
    ; default_headers : (Headers.name * Headers.value) list
          (** Set default headers (on the client) to be sent on every request. *)
    }

  val default : t
end

module Error : sig
  type common =
    [ `Exn of exn
    | `Protocol_error of H2.Error_code.t * string
    | `Msg of string
    ]

  type client =
    [ `Invalid_response_body_length of H2.Status.t * Headers.t
    | `Malformed_response of string
    | `Connect_error of string
    | common
    ]

  type server =
    [ `Bad_gateway
    | `Bad_request
    | `Internal_server_error
    | common
    ]

  type t =
    [ common
    | client
    | server
    ]

  val to_string : t -> string

  val pp_hum : Format.formatter -> t -> unit [@@ocaml.toplevel_printer]
end

module Body : sig
  type t

  type length =
    [ `Fixed of Int64.t
    | `Chunked
    | `Error of [ `Bad_request | `Bad_gateway | `Internal_server_error ]
    | `Unknown
    | `Close_delimited
    ]

  val length : t -> length

  val empty : t

  val of_stream : ?length:length -> Bigstringaf.t IOVec.t Lwt_stream.t -> t

  val of_string_stream : ?length:length -> string Lwt_stream.t -> t

  val of_string : string -> t

  val of_bigstring : ?off:int -> ?len:int -> Bigstringaf.t -> t

  val to_string : t -> (string, Error.t) Lwt_result.t

  val drain : t -> (unit, Error.t) Lwt_result.t

  val is_closed : t -> bool

  val closed : t -> (unit, Error.t) Lwt_result.t

  val when_closed : t -> ((unit, Error.t) result -> unit) -> unit

  (** {3 Traversal} *)

  val fold
    :  (Bigstringaf.t IOVec.t -> 'a -> 'a)
    -> t
    -> 'a
    -> ('a, Error.t) Lwt_result.t

  val fold_string
    :  (string -> 'a -> 'a)
    -> t
    -> 'a
    -> ('a, Error.t) Lwt_result.t

  val fold_s
    :  (Bigstringaf.t Faraday.iovec -> 'a -> 'a Lwt.t)
    -> t
    -> 'a
    -> ('a, Error.t) Lwt_result.t

  val fold_string_s
    :  (string -> 'a -> 'a Lwt.t)
    -> t
    -> 'a
    -> ('a, Error.t) Lwt_result.t

  val iter
    :  (Bigstringaf.t Faraday.iovec -> unit)
    -> t
    -> (unit, Error.t) Lwt_result.t

  val iter_string : (string -> unit) -> t -> (unit, Error.t) Lwt_result.t

  val iter_s
    :  (Bigstringaf.t Faraday.iovec -> unit Lwt.t)
    -> t
    -> (unit, Error.t) Lwt_result.t

  val iter_string_s
    :  (string -> unit Lwt.t)
    -> t
    -> (unit, Error.t) Lwt_result.t

  val iter_p
    :  (Bigstringaf.t Faraday.iovec -> unit Lwt.t)
    -> t
    -> (unit, Error.t) Lwt_result.t

  val iter_string_p
    :  (string -> unit Lwt.t)
    -> t
    -> (unit, Error.t) Lwt_result.t

  val iter_n
    :  ?max_concurrency:int
    -> (Bigstringaf.t Faraday.iovec -> unit Lwt.t)
    -> t
    -> (unit, Error.t) Lwt_result.t

  val iter_string_n
    :  ?max_concurrency:int
    -> (string -> unit Lwt.t)
    -> t
    -> (unit, Error.t) Lwt_result.t

  (** {3 Conversion to [Lwt_stream.t]} *)

  (** The functions below convert a [Piaf.Body.t] to an [Lwt_stream.t]. These
      functions should be used sparingly, and only when interacting with other
      APIs that require their argument to be a [Lwt_stream.t].

      These functions return a tuple of two elements. In addition to returning a
      [Lwt_stream.t], the tuple's second element is a promise that will sleep
      until the stream is consumed (and closed). This promise will resolve to
      [Ok ()] if the body was successfully transferred from the peer; otherwise,
      it will return [Error error] with an error of type [Error.t] detailing the
      failure that caused the body to not have been fully transferred from the
      peer. *)

  val to_stream
    :  t
    -> Bigstringaf.t IOVec.t Lwt_stream.t * (unit, Error.t) Lwt_result.t

  val to_string_stream : t -> string Lwt_stream.t * (unit, Error.t) Lwt_result.t
end

module Request : sig
  type t = private
    { meth : Method.t
    ; target : string
    ; version : Versions.HTTP.t
    ; headers : Headers.t
    ; scheme : Scheme.t
    ; body : Body.t
    }

  val create
    :  scheme:Scheme.t
    -> version:Versions.HTTP.t
    -> ?headers:Headers.t
    -> meth:Method.t
    -> body:Body.t
    -> string
    -> t

  val uri : t -> Uri.t

  val persistent_connection : t -> bool

  val pp_hum : Format.formatter -> t -> unit [@@ocaml.toplevel_printer]
end

module Response : sig
  type t = private
    { status : Status.t
    ; headers : Headers.t
    ; version : Versions.HTTP.t
    ; body : Body.t
    }

  val create
    :  ?version:Versions.HTTP.t
    -> ?headers:Headers.t
    -> ?body:Body.t
    -> Status.t
    -> t

  val of_string
    :  ?version:Versions.HTTP.t
    -> ?headers:Headers.t
    -> body:string
    -> Status.t
    -> t

  val of_bigstring
    :  ?version:Versions.HTTP.t
    -> ?headers:Headers.t
    -> body:Bigstringaf.t
    -> Status.t
    -> t

  val of_string_stream
    :  ?version:Versions.HTTP.t
    -> ?headers:Headers.t
    -> body:string Lwt_stream.t
    -> Status.t
    -> t

  val of_stream
    :  ?version:Versions.HTTP.t
    -> ?headers:Headers.t
    -> body:Bigstringaf.t IOVec.t Lwt_stream.t
    -> Status.t
    -> t

  val upgrade
    :  ?version:Versions.HTTP.t
    -> ?headers:Headers.t
    -> ((Gluten.impl -> unit) -> unit)
    -> t

  val of_file
    :  ?version:Versions.HTTP.t
    -> ?headers:Headers.t
    -> string
    -> t Lwt.t

  val persistent_connection : t -> bool

  val pp_hum : Format.formatter -> t -> unit [@@ocaml.toplevel_printer]
end

module Form : sig
  module Multipart : sig
    type t = private
      { name : string
      ; filename : string option
      ; content_type : string
      ; body : Body.t
      }

    val stream
      :  ?max_chunk_size:int
      -> Request.t
      -> (t Lwt_stream.t, Error.t) Lwt_result.t

    val assoc
      :  ?max_chunk_size:int
      -> Request.t
      -> ((string * t) list, Error.t) Lwt_result.t
  end
end

(** {2 Client -- Issuing requests} *)

(** There are two options for issuing requests with Piaf:

    + client: useful if multiple requests are going to be sent to the remote
      endpoint, avoids setting up a TCP connection for each request. Or if
      HTTP/1.0, you can think of this as effectively a connection manager.
    + oneshot: issues a single request and tears down the underlying connection
      once the request is done. Useful for isolated requests. *)

module Client : sig
  type t

  val create : ?config:Config.t -> Uri.t -> (t, Error.t) Lwt_result.t
  (** [create ?config uri] opens a connection to [uri] (initially) that can be
      used to issue multiple requests to the remote endpoint.

      A client instance represents a connection to a single remote endpoint, and
      the remaining functions in this module will issue requests to that
      endpoint only. *)

  val head
    :  t
    -> ?headers:(string * string) list
    -> string
    -> (Response.t, Error.t) Lwt_result.t

  val get
    :  t
    -> ?headers:(string * string) list
    -> string
    -> (Response.t, Error.t) Lwt_result.t

  val post
    :  t
    -> ?headers:(string * string) list
    -> ?body:Body.t
    -> string
    -> (Response.t, Error.t) Lwt_result.t

  val put
    :  t
    -> ?headers:(string * string) list
    -> ?body:Body.t
    -> string
    -> (Response.t, Error.t) Lwt_result.t

  val patch
    :  t
    -> ?headers:(string * string) list
    -> ?body:Body.t
    -> string
    -> (Response.t, Error.t) Lwt_result.t

  val delete
    :  t
    -> ?headers:(string * string) list
    -> ?body:Body.t
    -> string
    -> (Response.t, Error.t) Lwt_result.t

  val request
    :  t
    -> ?headers:(string * string) list
    -> ?body:Body.t
    -> meth:Method.t
    -> string
    -> (Response.t, Error.t) Lwt_result.t

  val shutdown : t -> unit Lwt.t
  (** [shutdown t] tears down the connection [t] and frees up all the resources
      associated with it. *)

  module Oneshot : sig
    val head
      :  ?config:Config.t
      -> ?headers:(string * string) list
      -> Uri.t
      -> (Response.t, Error.t) Lwt_result.t

    val get
      :  ?config:Config.t
      -> ?headers:(string * string) list
      -> Uri.t
      -> (Response.t, Error.t) Lwt_result.t

    val post
      :  ?config:Config.t
      -> ?headers:(string * string) list
      -> ?body:Body.t
      -> Uri.t
      -> (Response.t, Error.t) Lwt_result.t

    val put
      :  ?config:Config.t
      -> ?headers:(string * string) list
      -> ?body:Body.t
      -> Uri.t
      -> (Response.t, Error.t) Lwt_result.t

    val patch
      :  ?config:Config.t
      -> ?headers:(string * string) list
      -> ?body:Body.t
      -> Uri.t
      -> (Response.t, Error.t) Lwt_result.t

    val delete
      :  ?config:Config.t
      -> ?headers:(string * string) list
      -> ?body:Body.t
      -> Uri.t
      -> (Response.t, Error.t) Lwt_result.t

    val request
      :  ?config:Config.t
      -> ?headers:(string * string) list
      -> ?body:Body.t
      -> meth:Method.t
      -> Uri.t
      -> (Response.t, Error.t) Lwt_result.t
    (** Use another request method. *)
  end
end

module Server : sig
  module Service : sig
    type ('req, 'resp) t = 'req -> 'resp Lwt.t
  end

  module Middleware : sig
    type ('req, 'resp, 'req', 'resp') t =
      ('req, 'resp) Service.t -> ('req', 'resp') Service.t

    type ('req, 'resp) simple = ('req, 'resp, 'req, 'resp) t
  end

  module Handler : sig
    type 'ctx ctx =
      { ctx : 'ctx
      ; request : Request.t
      }

    type 'ctx t = ('ctx ctx, Response.t) Service.t

    val not_found : 'a -> Response.t Lwt.t
  end

  module Error_response : sig
    type t
  end

  type 'ctx ctx = 'ctx Handler.ctx =
    { ctx : 'ctx
    ; request : Request.t
    }

  type 'ctx t = 'ctx Handler.t

  val create
    :  ?config:Config.t
    -> ?error_handler:
         (Unix.sockaddr
          -> ?request:Request.t
          -> respond:(headers:Headers.t -> Body.t -> Error_response.t)
          -> Httpaf.Server_connection.error
          -> Error_response.t Lwt.t)
    -> Unix.sockaddr Handler.t
    -> Unix.sockaddr
    -> Httpaf_lwt_unix.Server.socket
    -> unit Lwt.t
end

module Cookies : sig
  type expiration =
    [ `Session
    | `Max_age of int64
    ]

  type same_site =
    [ `None
    | `Lax
    | `Strict
    ]

  type cookie = string * string

  module Set_cookie : sig
    type t

    val make
      :  ?expiration:expiration
      -> ?path:string
      -> ?domain:string
      -> ?secure:bool
      -> ?http_only:bool
      -> ?same_site:same_site
      -> cookie
      -> t

    val with_expiration : t -> expiration -> t

    val with_path : t -> string -> t

    val with_domain : t -> string -> t

    val with_secure : t -> bool -> t

    val with_http_only : t -> bool -> t

    val with_same_site : t -> same_site -> t

    val serialize : t -> cookie

    val parse : Headers.t -> (string * t) list

    val key : t -> string

    val value : t -> string
  end

  module Cookie : sig
    val parse : Headers.t -> (string * string) list

    val serialize : (string * string) list -> cookie
  end
end
