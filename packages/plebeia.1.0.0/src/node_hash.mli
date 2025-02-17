(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2019,2020 DaiLambda, Inc. <contact@dailambda.jp>            *)
(*                                                                           *)
(* Permission is hereby granted, free of charge, to any person obtaining a   *)
(* copy of this software and associated documentation files (the "Software"),*)
(* to deal in the Software without restriction, including without limitation *)
(* the rights to use, copy, modify, merge, publish, distribute, sublicense,  *)
(* and/or sell copies of the Software, and to permit persons to whom the     *)
(* Software is furnished to do so, subject to the following conditions:      *)
(*                                                                           *)
(* The above copyright notice and this permission notice shall be included   *)
(* in all copies or substantial portions of the Software.                    *)
(*                                                                           *)
(* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR*)
(* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  *)
(* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL   *)
(* THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER*)
(* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING   *)
(* FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER       *)
(* DEALINGS IN THE SOFTWARE.                                                 *)
(*                                                                           *)
(*****************************************************************************)
(** { 1 Node hash } *)

type t 
(** the type for the node hash.
    
    Non Extenders have the fixed 224bit (28byte) length.

    Extenders have variable lengths from 30 bytes to 256 bytes.
*)

val encoding : t Data_encoding.t

val to_hex_string : t -> string
(** Hex string representation of [t] *)
   
    (** Compute node hash of a node *)

val of_internal : t -> t -> t
val of_bud : t option -> t
val of_leaf : Value.t -> t
val of_extender : Segment.t -> t -> t

val prefix : t -> Hash.t
(** Get the first 224bits of the node hash *)

val compute :  Context.t -> Node.node -> (Node.view * t)
(** Compute the node hash of the given node.  It may traverse the node
    loading subnodes from the disk to obtain or compute the node hashes of 
    subnodes if necessary. 
*)
