(******************************************************************************)
(*                                                                            *)
(*                                    Fix                                     *)
(*                                                                            *)
(*                       François Pottier, Inria Paris                        *)
(*                                                                            *)
(*  Copyright Inria. All rights reserved. This file is distributed under the  *)
(*  terms of the GNU Library General Public License version 2, with a         *)
(*  special exception on linking, as described in the file LICENSE.           *)
(*                                                                            *)
(******************************************************************************)

(* -------------------------------------------------------------------------- *)

(* A type alone. *)

module type TYPE = sig
  type t
end

(* -------------------------------------------------------------------------- *)

(* An ordered type. A hashed type. These are standard notions. *)

module type OrderedType =
  Map.OrderedType

module type HashedType =
  Hashtbl.HashedType

(* -------------------------------------------------------------------------- *)

(* A type whose elements can be enumerated. *)

module type FINITE_TYPE = sig
  type t
  val foreach: (t -> unit) -> unit
end

(* -------------------------------------------------------------------------- *)

(* Association maps. *)

(* Following the convention of the ocaml standard library, [find] raises the
   exception [Not_found] when the key is not in the domain of the map. In
   contrast, [get] returns an option. *)

(* Persistent maps. The empty map is a constant. Insertion creates a new map. *)

(* This is a fragment of the standard signature [Map.S]. *)

module type PERSISTENT_MAPS = sig
  type key
  type 'data t
  val empty: 'data t
  val add: key -> 'data -> 'data t -> 'data t
  val find: key -> 'data t -> 'data
  val iter: (key -> 'data -> unit) -> 'data t -> unit
end

(* Imperative maps. A fresh empty map is produced by [create].
   Insertion updates a map in place.
   [clear] empties an existing map. *)

(* The order of the arguments to [add] and [find] is consistent with the order
   used in [PERSISTENT_MAPS] above. Thus, it departs from the convention used
   in OCaml's [Hashtbl] module. *)

module type MINIMAL_IMPERATIVE_MAPS = sig
  type key
  type 'data t
  val create: unit -> 'data t
  val add: key -> 'data -> 'data t -> unit
  val find: key -> 'data t -> 'data
end

module type IMPERATIVE_MAPS = sig
  include MINIMAL_IMPERATIVE_MAPS
  val clear: 'data t -> unit
  val iter: (key -> 'data -> unit) -> 'data t -> unit
end

(* -------------------------------------------------------------------------- *)

(* Properties. *)

(* The type [property] must form a partial order. It must be equipped with a
   least element [bottom] and with an equality test [equal]. (In the function
   call [equal p q], it is permitted to assume that [p <= q] holds.) We do not
   require an ordering test [leq]. We do not require a join operation [lub].
   We do require the ascending chain condition: every monotone sequence must
   eventually stabilize. *)

(* The function [is_maximal] determines whether a property [p] is maximal with
   respect to the partial order. Only a conservative check is required: in any
   event, it is permitted for [is_maximal p] to be [false]. If [is_maximal p]
   is [true], then [p] must have no strict upper bound. In particular, in the
   case where properties form a lattice, this means that [p] must be the top
   element. *)

module type PROPERTY = sig
  type property
  val bottom: property
  val equal: property -> property -> bool
  val is_maximal: property -> bool
end

(* -------------------------------------------------------------------------- *)

(* Memoizers -- higher-order functions that construct memoizing functions. *)

module type MEMOIZER = sig
  (* A type of keys. *)
  type key
  (* A memoization combinator for this type. *)
  val memoize: (key -> 'a) -> (key -> 'a)
  (* A recursive memoization combinator for this type. *)
  val fix: ((key -> 'a) -> (key -> 'a)) -> (key -> 'a)
  (* [defensive_fix] works like [fix], except it additionally detects circular
     dependencies, which can arise if the second-order function supplied by
     the user does not follow a well-founded recursion pattern. When the user
     invokes [f x], where [f] is the function returned by [defensive_fix], if
     a cyclic dependency is detected, then [Cycle (zs, z)] is raised, where
     the list [zs] begins with [z] and continues with a series of intermediate
     keys, leading back to [z]. Note that undetected divergence remains
     possible; this corresponds to an infinite dependency chain, without a
     cycle. *)
  exception Cycle of key list * key
  val defensive_fix: ((key -> 'a) -> (key -> 'a)) -> (key -> 'a)
end

(* -------------------------------------------------------------------------- *)

(* Tabulators -- higher-order functions that construct tabulated functions. *)

(* Like memoization, tabulation guarantees that, for every key [x], the image
   [f x] is computed at most once. Unlike memoization, where this computation
   takes place on demand, in the case of tabulation, the computation of every
   [f x] takes place immediately, when [tabulate] is invoked. The graph of the
   function [f], a table, is constructed and held in memory. *)

module type TABULATOR = sig
  (* A type of keys. *)
  type key
  (* A tabulation combinator for this type. *)
  val tabulate: (key -> 'a) -> (key -> 'a)
end

(* -------------------------------------------------------------------------- *)

(* Solvers -- higher-order functions that compute the least solution of a
   monotone system of equations. *)

module type SOLVER = sig

  type variable
  type property

  (* A valuation is a mapping of variables to properties. *)
  type valuation = variable -> property

  (* A right-hand side, when supplied with a valuation that gives
     meaning to its free variables, evaluates to a property. More
     precisely, a right-hand side is a monotone function of
     valuations to properties. *)
  type rhs = valuation -> property

  (* A system of equations is a mapping of variables to right-hand
     sides. *)
  type equations = variable -> rhs

  (* [lfp eqs] produces the least solution of the system of monotone
     equations [eqs]. *)

  (* It is guaranteed that, for each variable [v], the application [eqs v] is
     performed at most once (whereas the right-hand side produced by this
     application is, in general, evaluated multiple times). This guarantee can
     be used to perform costly pre-computation, or memory allocation, when [eqs]
     is applied to its first argument. *)

  (* When [lfp] is applied to a system of equations [eqs], it performs no
     actual computation. It produces a valuation, [get], which represents
     the least solution of the system of equations. The actual fixed point
     computation takes place, on demand, when [get] is applied. *)
  val lfp: equations -> valuation

end

(* -------------------------------------------------------------------------- *)

(* Directed, rooted graphs. *)

module type GRAPH = sig
  type t
  val foreach_root: (t -> unit) -> unit
  val foreach_successor: t -> (t -> unit) -> unit
end

(* -------------------------------------------------------------------------- *)

(* Numberings. *)

(* A numbering of (a subset of) a type [t] is a triple of an integer [n] and
   two functions [encode] and [decode] which represent an isomorphism between
   this subset of [t] and the interval [0..n). *)

module type NUMBERING = sig
  type t
  val n: int
  val encode: t -> int
  val decode: int -> t
end

(* -------------------------------------------------------------------------- *)

(* Injections. *)

(* An injection of [t] into [u] is an injective function of type [t -> u].
   Because [encode] is injective, [encode x] can be thought of as the identity
   of the object [x]. *)

module type INJECTION = sig
  type t
  type u
  val encode: t -> u
end