(******************************************************************************)
(*                                                                            *)
(*                                  Monolith                                  *)
(*                                                                            *)
(*                              François Pottier                              *)
(*                                                                            *)
(*  Copyright Inria. All rights reserved. This file is distributed under the  *)
(*  terms of the GNU Lesser General Public License as published by the Free   *)
(*  Software Foundation, either version 3 of the License, or (at your         *)
(*  option) any later version, as described in the file LICENSE.              *)
(*                                                                            *)
(******************************************************************************)

open Monolith

module R = Reference
module C = Candidate

(* -------------------------------------------------------------------------- *)

(* Declare an abstract type [map], which is implemented in two different
   ways by the reference implementation and by the candidate implementation. *)

(* We test this map with integer keys and integer values. *)

let check model =
  C.check model, constant "check"

let map =
  declare_abstract_type ~check ()

(* -------------------------------------------------------------------------- *)

(* Propose several key generators. *)

(* [arbitrary_key] produces an arbitrary key within a certain interval.
   The interval must be reasonably small, otherwise the fuzzer wastes
   time trying lots of different keys. *)

let arbitrary_key =
  Gen.lt 16

(* [extreme_key] produces the key [min_int] or [max_int]. *)

let extreme_key () =
  if Gen.bool() then min_int else max_int

(* [present_key m] produces a key that is present in the map [m]. Its
   implementation is not efficient, but we will likely be working with
   very small maps, so this should be acceptable. *)

let present_key (m : R.map) () =
  let n = R.cardinal m in
  let i = Gen.int n () in
  let key, _value = List.nth (R.bindings m) i in
  key

(* [key m] combines the above generators. *)

let key m () =
  if Gen.bool() then
    arbitrary_key()
  else if Gen.bool() then
    extreme_key()
  else
    present_key m ()

(* Declare the concrete type [key]. *)

let key m =
  int_within (key m)

(* -------------------------------------------------------------------------- *)

(* Declare the type [value] as an alias for [int]. *)

(* We generate values within a restricted range, because we do not expect
   that a wide range of values is required in order to expose bugs. *)

let value =
  lt 16

(* -------------------------------------------------------------------------- *)

(* Declare the operations. *)

let () =

  let spec = map in
  declare "empty" spec R.empty C.empty;

  let spec = rot3 (map ^>> fun m -> key m ^> value ^> map) in
  declare "add" spec R.add C.add;

  let spec = key R.empty ^> value ^> map in
  declare "singleton" spec R.singleton C.singleton;

  let spec = map ^> map ^> map in
  let k x _y = x in
  declare "union (fun x _y -> x)" spec (R.union k) (C.union k);
    (* We pass the [union] operation a non-commutative function,
       namely [k], so as to possibly detect a bug where [union]
       passes the two values in the wrong order to the user function. *)

  let spec = map ^> int in
  declare "cardinal" spec R.cardinal C.cardinal;

  (* [find] can raise [Not_found], so we use the arrow combinator [^!>]. *)
  let spec = rot2 (map ^>> fun m -> key m ^!> value) in
  declare "find" spec R.find C.find;

  ()

(* -------------------------------------------------------------------------- *)

(* Start the engine! *)

let () =
  let fuel = 20 in
  main fuel
