(*
 * Copyright (c) 2018-2021 Tarides <contact@tarides.com>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open! Import

module type S = sig
  include Irmin.CONTENT_ADDRESSABLE_STORE

  val add : 'a t -> value -> key Lwt.t
  (** Overwrite [add] to work with a read-only database handler. *)

  val unsafe_add : 'a t -> key -> value -> unit Lwt.t
  (** Overwrite [unsafe_add] to work with a read-only database handler. *)

  val unsafe_append :
    ensure_unique:bool -> overcommit:bool -> 'a t -> key -> value -> unit

  val unsafe_mem : 'a t -> key -> bool
  val unsafe_find : check_integrity:bool -> 'a t -> key -> value option

  val generation : 'a t -> int63
  (** The number of times that {!clear} has been called on this store. *)

  val clear_keep_generation : 'a t -> unit Lwt.t
  val close : _ t -> unit Lwt.t
  val batch : read t -> ([ read | write ] t -> 'a Lwt.t) -> 'a Lwt.t
end

module type Maker = sig
  type key

  (** Save multiple kind of values in the same pack file. Values will be
      distinguished using [V.kind], so they have to all be different. *)
  module Make (V : Pack_value.S with type hash := key) :
    S with type key = key and type value = V.t
end

module type Sigs = sig
  module type S = S

  module Closeable (CA : S) : sig
    include S with type key = CA.key and type value = CA.value

    val make_closeable : 'a CA.t -> 'a t
    val get_open_exn : 'a t -> 'a CA.t
  end
end
