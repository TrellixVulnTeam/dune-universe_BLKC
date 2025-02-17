(******************************************************************************)
(*                                                                            *)
(*                                    Sek                                     *)
(*                                                                            *)
(*          Arthur Charguéraud, Émilie Guermeur and François Pottier          *)
(*                                                                            *)
(*  Copyright Inria. All rights reserved. This file is distributed under the  *)
(*  terms of the GNU Lesser General Public License as published by the Free   *)
(*  Software Foundation, either version 3 of the License, or (at your         *)
(*  option) any later version, as described in the file LICENSE.              *)
(*                                                                            *)
(******************************************************************************)

open PublicTypeAbbreviations
open PrivateSignatures

module[@inline] Make
    (EChunk : ECHUNK)
= struct

module EChunk = EChunk
module View = EChunk.View
type 'a chunk = 'a EChunk.t
type view = View.view

(* A shareable chunk, or schunk, is a hybrid, possibly ephemeral, possibly
   persistent data structure. It serves as a wrapper for an underlying
   ephemeral chunk, which we refer to as its [support]. Only a part of this
   underlying chunk, which we refer to as the [view], is of interest. *)

(* A schunk keeps track of the total [weight] of the elements that it
   contains. One element does not necessarily have weight one; a measure [m]
   tells us how much each element weighs. *)

(* A schunk is either *shared* or *uniquely owned*. When it is shared, it
   cannot be modified. (Yet, the underlying chunk *can* be modified, provided
   the modifications take place *outside* the view of every owner.) When it is
   uniquely owned (which means that the underlying chunk is uniquely owned as
   well), it can be modified, and the underlying chunk can be modified as
   well. In that case, modifications within the [view] are permitted. *)

(* A subtle point is that one cannot tell, by looking at a schunk, whether it
   is shared or uniquely owned. Indeed, a schunk stores an optional owner in
   its [owner] field. The meaning of this field is as follows:

   * If this field is [Owner.none], then this schunk is shared.

   * If this field holds an owner [p.owner], then this schunk may be shared or
     uniquely owned. Ownership is in the eye of the beholder. Every operation
     expects the identity [o] of the caller as an argument. If [p.owner] and
     [o] are in the relation [Owner.is_uniquely_owned], then the schunk is
     uniquely owned; otherwise, it is shared. *)

(* This convention is in a sense very fragile, as it is entirely up to the
   caller of an operation to provide an appropriate identity [o]. Passing
   an incorrect identity can cause a shared schunk to be considered uniquely
   owned or vice-versa, resulting in incorrect behavior. *)

(* Nevertheless, there is a good reason to adopt this convention. Indeed, it
   allows us to change the ownership regime of an arbitrary number of schunks
   at zero runtime cost, just by changing the identity of the caller. E.g.,
   suppose we have a collection of uniquely-owned schunks, marked with owner
   [o]. In order to transition all of these schunks to shared mode, all we
   have to do is change our own identity to something other than [o]. *)

(* A schunk can be created either uniquely-owned or shared. Later on, it can
   transition from uniquely-owned to shared, but not other way around: that
   would be unsafe, as we have no way of tracking how many pointers to a
   shared schunk exist. It is again up to the user to obey this restriction. *)

(* The Boolean field [shared] records whether this schunk has been found at
   least once to be shared; this implies that it must always be found to be
   shared in the future. This field allows us to detect a violation by the
   user of the above restriction. It is used only for debugging purposes. *)

(* The Boolean field [uid] assigns a unique identity to each schunk. It is
   used only for debugging purposes. *)

(* The fields [shared] and [uid] disappear when the code is compiled in
   release mode. *)

type 'a t = {
  owner : owner;
  support : 'a chunk;
  mutable view : view;
  mutable weight : weight;
#ifdef dev
  mutable shared : bool;
  uid : int;
#endif
}

(* -------------------------------------------------------------------------- *)

(* Logging support. *)

let debug =
  false

let[@inline] log format =
  if debug then
    Printf.fprintf stderr format
  else
    Printf.ifprintf stderr format

(* -------------------------------------------------------------------------- *)

(* Interpreting a measure as a weight function. *)

type 'a measure =
| MUnit         : 'a measure   (* maps every value to 1 *)
| MSWeight : 'a t measure (* maps a schunk to its weight *)

let[@inline] apply (type a) (m : a measure) (x : a) : weight =
  match m with
  | MUnit ->
      1
  | MSWeight ->
      x.weight

(* -------------------------------------------------------------------------- *)

(* Iteration. *)

let[@inline] iter_segments pov p yield =
  View.iter_segments pov (p.support, p.view) yield

let iteri_segments_front schunk yield =
  let head = ref 0 in
  iter_segments Front schunk (fun ((_a, _i, k) as seg) ->
    yield !head seg;
    head := !head + k
  )

let iter pov f p =
  ArrayExtra.iter iter_segments pov f p

let fold_left f seed p =
  Adapters.fold_left (iter Front) f seed p

let to_list p =
  Adapters.to_list (iter Back) p

(* -------------------------------------------------------------------------- *)

(* The unique-ownership test. *)

(* [is_uniquely_owned p o] determines whether the schunk [p] is uniquely
   owned by the owner [o]. *)

let[@inline] is_uniquely_owned p o =
  Owner.is_uniquely_owned p.owner o

#ifdef dev
let is_uniquely_owned p o =
  let unique = is_uniquely_owned p o in
  if p.shared && unique then begin
    (* This [schunk] has been found to be shared in the past, yet is now
       found to be uniquely owned. This should never happen! *)
    log "schunk uid = %d is uniquely owned again (owner %s)!\n%!"
      p.uid (Owner.show o);
    assert false
  end;
  if unique then begin
    log "schunk uid = %d is uniquely owned by owner %s.\n%!"
      p.uid (Owner.show o)
  end
  else begin
    (* This [schunk] is regarded as shared now. Record this fact. *)
    p.shared <- true;
    log "schunk uid = %d is now shared (p.owner = %s, o = %s).\n%!"
      p.uid (Owner.show p.owner) (Owner.show o)
  end;
  (* Return. *)
  unique
#endif

(* -------------------------------------------------------------------------- *)

(* Alignment. *)

(* [is_aligned p] determines whether the view covers all of the support. *)

let[@inline] is_aligned p =
  View.is_aligned p.support p.view

(* -------------------------------------------------------------------------- *)

(* Validity of a schunk. *)

(* [check m o p] verifies that the schunk [p] is valid in the eyes of
   an owner or co-owner [o]. *)

let check_except_weight o p =
  (* The support must be a valid chunk. *)
  EChunk.check p.support;
  (* The view must be a valid view on the support. *)
  View.check p.support p.view;
  (* If the schunk [p] is uniquely owned, then the view must
     in fact cover all of the support. *)
  assert (if is_uniquely_owned p o then is_aligned p else true)

let check m o p =
  check_except_weight o p;
  (* The weight stored in the [weight] field must in fact be the sum of
     the weights of the elements stored in this schunk. *)
  assert (p.weight = fold_left (fun sum x -> sum + apply m x) 0 p)

(* Ensure [check] has zero cost in release mode. *)

let[@inline] check m o p =
  assert (check m o p; true)

let[@inline] validate_except_weight o p =
  assert (check_except_weight o p; true);
  p

(* -------------------------------------------------------------------------- *)

(* Operations on dummy chunks. *)

let[@inline] is_dummy p =
  EChunk.is_dummy p.support

(* A dummy schunk is *invalid*. No operation must be applied to it,
   with the exception of [is_empty] and [is_full], both of which
   return [true] for a dummy schunk.
   It is used as a default value in a chunk of chunks.*)

let dummy d =
  let owner = Owner.none
  and support = EChunk.dummy d
  and view = View.dummy
  and weight = 0 in
  { owner; support; view; weight;
    #ifdef dev
    shared = false; uid = (-1);
    #endif
  }

(* -------------------------------------------------------------------------- *)

(* Printing. *)

(* The [model] pseudo-field is printed only when [m] is [MUnit],
   otherwise this creates too much noise. *)

let print m print p =
  let open PPrint in
  let open PPrint.OCaml in
  if is_dummy p then
    !^ "<dummy>"
  else
  let model () =
    (* The function [to_list] invokes [iter], which can fail if
       the chunk is ill-formed. Catch these exceptions. *)
    try
      flowing_list print (to_list p)
    with
    | Assert_failure (s, i, j) ->
        utf8format "<cannot print: Assert_failure (%S, %d, %d)>" s i j
    | Invalid_argument s ->
        utf8format "<cannot print: Invalid_argument %S>" s
  in
  record "schunk" ([
#ifdef dev
    "uid", int p.uid;
#endif
    "weight", int p.weight;
    "owner", !^ (Owner.show p.owner);
    "view", View.print p.view;
    "support", View.print (EChunk.view p.support);
  ] @ (if m = MUnit then [
    "model", model();
  ] else []))

(* -------------------------------------------------------------------------- *)

(* Basic accessors. *)

let[@inline] default p =
  EChunk.default p.support

let[@inline] length p =
  (* It is permitted to apply this function to a dummy schunk. *)
  View.size p.view

let[@inline] weight p =
  p.weight

let[@inline] data p =
  EChunk.data p.support

let[@inline] support p =
  p.support

let[@inline] capacity p =
  EChunk.capacity p.support

let[@inline] is_empty p =
  length p = 0

let[@inline] is_full p =
  length p = capacity p

let[@inline] remaining_length pov i p =
  match pov with
  | Front ->
      length p - i
  | Back ->
      i + 1

let[@inline] segment pov i k p =
  assert (0 <= i && i < length p);
  assert (0 <= k && k <= remaining_length pov i p);
  View.segment pov i k p.support p.view

let[@inline] segment_max pov i p =
  assert (0 <= i && i < length p);
  let k = remaining_length pov i p in
  segment pov i k p

(* -------------------------------------------------------------------------- *)

(* Construction. *)

#ifdef dev
let uid =
  let next = ref 0 in
  fun () ->
    let uid = !next in
    next := uid + 1;
    uid
#endif

let create d n o =
  let owner = o in
  let support = EChunk.create d n in
  let view = EChunk.view support in
  assert (View.size view = 0);
  let weight = 0 in
  validate_except_weight o
    { owner; support; view; weight;
      #ifdef dev
      shared = false; uid = uid();
      #endif
    }

let of_chunk_destructive c o =
  let owner = o
  and support = c
  and view = EChunk.view c
  and weight = EChunk.length c in (* this assumes unit element weight *)
  validate_except_weight o
    { owner; support; view; weight;
      #ifdef dev
      shared = false; uid = uid();
      #endif
    }

let[@inline] of_array_segment d n a head size o =
  let c = EChunk.of_array_segment d n a head size in
  of_chunk_destructive c o

let[@inline] make d n k v o =
  let c = EChunk.make d n k v in
  of_chunk_destructive c o

let[@inline] init d n k i f o =
  let c = EChunk.init d n k i f in
  of_chunk_destructive c o

(* [share p o view weight] creates a new schunk that shares the support of
   the existing schunk [p]. Therefore, this new schunk is immediately
   created in shared mode. The schunk [p] must itself be shared already with
   respect to owner [o]. *)

let share p o view weight =
  (* [p] must be shared. *)
  assert (not (is_uniquely_owned p o));
  (* The new chunk is shared. *)
  let owner = Owner.none
  (* The support is not copied. *)
  and support = p.support in
  validate_except_weight o
    { owner; support; view; weight;
      #ifdef dev
      shared = true; uid = uid();
      #endif
    }

(* [sub c o view weight] creates a new schunk whose support is a new chunk,
   obtained by copying the view [view] of the chunk [c]. Therefore, it is
   safe to regard this new schunk as uniquely owned. Its owner is set to
   [o], which may or may not be [Owner.none]. *)

(* TODO: we may also need a [sub] function that preserves sharing? *)

let sub c o view weight =
  (* Part of the existing chunk is copied, and a new schunk is allocated. *)
  let support = View.sub c view
  and owner = o in
  let p =
    { owner; support; view; weight;
      #ifdef dev
      shared = false; uid = uid();
        (* It is safe to set [shared] to [false] even if [o] is
           [Owner.none]; this means that the schunk is not yet
           shared. We could also initialize the field [shared]
           to [o = Owner.none]. *)
      #endif
    }
  in
  assert (is_aligned p);
  validate_except_weight o p

let[@inline] copy p o =
  (* Because the new schunk is uniquely owned by [o] (unless [o] is
     [Owner.none]), it must satisfy [is_aligned]. Thus, we must not simply
     copy the underlying chunk; we must restrict its view to our view. In
     other words, we must not use [EChunk.copy]; we must use [View.sub]. *)
  (* Regardless of whether the new schunk is uniquely owned or shared, it is
     permitted and desirable to copy only the data in [p.view]. Copying more
     would create a memory leak. *)
  sub p.support o p.view p.weight

(* -------------------------------------------------------------------------- *)

(* Destruction. *)

(* [to_chunk] is the reverse operation of [of_chunk_destructive]. Like it, it
   assumes that every element has unit weight. *)

(* If [p] is uniquely owned, then it is destroyed and its support is re-used
   directly; no copy is required. If [p] is shared, then a copy is performed
   and a new chunk is allocated. *)

let to_chunk p o =
  check MUnit o p;
  if is_uniquely_owned p o then begin
    assert (is_aligned p);
    p.support
  end
  else
    View.sub p.support p.view

(* -------------------------------------------------------------------------- *)

(* Push. *)

(* [push_unique] deals with the case where [p] is uniquely owned. Then,
   both the schunk [p] and its support are updated in place. *)

let[@inline] push_unique pov p x m =
  (* Because [p] is uniquely owned, it is aligned with its support. *)
  assert (is_aligned p);
  (* This implies that its support is not full. *)
  assert (not (EChunk.is_full p.support));
  (* Push [x] onto the support. *)
  EChunk.push pov p.support x;
  (* Update [p]'s view and weight. *)
  p.view <- View.push pov p.support p.view;
  p.weight <- p.weight + apply m x;
  p

(* [push_shared] deals with the case where [p] is shared. Then, [p] cannot
   be mutated. Its support *can* be updated in place *if* the required update
   is just a push (that is, if [p] and its support are flush) *and* this push
   operation is permitted (that is, the support is not full). *)

let[@inline] push_shared pov p x m o =
  let support, owner, shared =
    if View.is_flush pov p.support p.view &&
       not (EChunk.is_full p.support)
    then
      (* Update the support in place. No copy required.
         The new schunk will be shared. *)
      p.support, p.owner, true
    else
      (* Allocate a fresh support. This is copy-on-write.
         The new schunk will be uniquely owned, unless [o]
         is [Owner.none]. *)
      View.sub p.support p.view, o, false
  in
  (* The following code is equivalent to
     [let p = { p with owner; support } in
      push_unique pov p x m]. *)
  assert (View.is_flush pov support p.view);
  assert (not (EChunk.is_full support));
  EChunk.push pov support x;
  let view = View.push pov support p.view
  and weight = p.weight + apply m x in
  { owner; support; view; weight;
    #ifdef dev
    shared; uid = uid();
    #endif
  }

let[@inline] push pov p x m o =
  assert (not (is_full p));
  if is_uniquely_owned p o then
    push_unique pov p x m
  else
    push_shared pov p x m o

(* -------------------------------------------------------------------------- *)

(* Pop. *)

(* [pop_unique] deals with the case where [p] is uniquely owned. Then, both
   the schunk [p] and its support are updated in place. *)

let[@inline] pop_unique pov p m =
  (* Because [p] is uniquely owned, it is aligned with its support. *)
  assert (is_aligned p);
  (* Pop an element [x] off the support. *)
  let x = EChunk.pop pov p.support in
  (* Update [p]'s view and weight. *)
  p.view <- View.pop pov p.support p.view;
  p.weight <- p.weight - apply m x;
  x, p

(* [pop_shared] deals with the case where [p] is shared. Then, neither [p]
   nor its support can be updated in place. *)

let[@inline] pop_shared pov p m o =
  (* Read the first element of the [view] view. *)
  let x = View.peek pov p.support p.view in
  (* Reduce the [view] view and the [weight]. *)
  let view = View.pop pov p.support p.view
  and weight = p.weight - apply m x in
  (* Allocate a new schunk, which shares the support of [p]. *)
  x, share p o view weight

let[@inline] pop pov p m o =
  assert (not (is_empty p));
  if is_uniquely_owned p o then
    pop_unique pov p m
  else
    pop_shared pov p m o

(* -------------------------------------------------------------------------- *)

(* Peek, get, set. *)

let[@inline] peek pov p =
  View.peek pov p.support p.view

let[@inline] get p i =
  assert (0 <= i && i < length p);
  View.get p.support p.view i

(* [set_unique] deals with the case where [p] is uniquely owned.
   [p] is updated in place. *)

let[@inline] set_unique p i x delta =
  (* We do not assert that the schunk is uniquely owned, because
     this code is also called by [set_shared], where [p] is a fresh
     schunk and [o] is possibly [Owner.none]. *)
  p.weight <- p.weight + delta;
  View.set p.support p.view i x;
  p

(* [set_shared] deals with the case where [p] is shared. *)

(* A new schunk is allocated, unless we find that [x] is physically equal to
   the element that it replaces *and* [delta] is zero. *)

let[@inline] set_shared p i x delta o =
  if delta = 0 && x == get p i then
    p
  else
    set_unique (copy p o) i x delta

(* [set p i x delta o] replaces the element found at index [i] in the sequence
   [p] with the value [x]. [i] must be comprised between 0 included and
   [length c] excluded. [delta] must be the difference between the weight of
   [x] and the weight of the element that is replaced. *)

(* A word of caution: if elements are mutable, then *when* their weight is
   computed matters. This is why [set] requires [delta] as an argument instead
   of computing [apply m x - apply m (get p i)] by itself; this computation
   does not make sense. *)

let[@inline] set p i x delta o =
  assert (0 <= i && i < length p);
  if is_uniquely_owned p o then
    set_unique p i x delta
  else
    set_shared p i x delta o

(* -------------------------------------------------------------------------- *)

(* Concatenation. *)

(* [concat_unique] deals with the case where [p2] is uniquely owned,
   and takes a [pov] parameter, so [p1] can be concatenated (in place)
   either at the front or at the back of [p2]. *)

(* This is very much like [push_unique]. *)

let[@inline] concat_unique pov p1 p2 =
  (* Because [p2] is uniquely owned, it is aligned with its support. *)
  assert (is_aligned p2);
  (* Push all of the data from [p1] at the front or back of [p2]. *)
  let view = View.copy pov p1.support p1.view p2.support p2.view in
  (* Update [p2] in place. *)
  p2.view <- view;
  p2.weight <- p1.weight + p2.weight;
  p2

(* [concat_shared] deals with the case where [p1] and [p2] are shared. *)

(* We optimize the cases where the support of one schunk has enough room to
   accommodate the data from the other schunk. If desired, these optimizations
   can be safely disabled by setting [optimize] to [false]. *)

let optimize =
  true

let concat_shared p1 p2 o =
  (* Optimization 1. The support of [p1] has free space at the end of [p1]'s
     view, and it has enough free space to copy all of the data from [p2]. *)
  if optimize &&
     View.is_flush Back p1.support p1.view &&
     EChunk.length p1.support + length p2 <= capacity p1
       (* Note that [EChunk.length p1.support] is not [length p1]. The
          support of [p1] can contain live data outside of [p1]'s view. *)
  then begin
    (* Push all of the data from [p2] onto the end of [p1]. *)
    let view = View.copy Back p2.support p2.view p1.support p1.view in
    (* No new chunk is allocated. The new schunk must be considered shared. *)
    share p1 o view (p1.weight + p2.weight)
  end
  (* Optimization 2 (symmetric). *)
  else if optimize &&
          View.is_flush Front p2.support p2.view &&
          length p1 + EChunk.length p2.support <= capacity p2
  then begin
    (* Push all of the data from [p1] in front of [p2]. *)
    let view = View.copy Front p1.support p1.view p2.support p2.view in
    (* No new chunk is allocated. The new schunk must be considered shared. *)
    share p2 o view (p1.weight + p2.weight)
  end
  (* General case. *)
  else begin
    (* Neither support can be reused. A new chunk must be allocated. *)
    let support = EChunk.create (default p1) (capacity p1) in
    let view = EChunk.view support in
    assert (View.size view = 0);
    let view = View.copy Back p1.support p1.view support view in
    let view = View.copy Back p2.support p2.view support view in
    assert (view = EChunk.view support);
    (* Allocate a new schunk, which can be considered uniquely owned. *)
    let owner = o
    and weight = p1.weight + p2.weight in
    { owner; support; view; weight;
      #ifdef dev
      shared = false; uid = uid();
      #endif
    }
  end

let[@inline] concat p1 p2 o =
  (* We require the two schunks to have the same capacity, so that, when
     we allocate a new chunk, we do not have a choice as to its capacity. *)
  assert (capacity p1 = capacity p2);
  (* The concatenated data must fit in a single chunk. *)
  assert (length p1 + length p2 <= capacity p2);
  (* Select an appropriate case. *)
  if is_uniquely_owned p1 o then
    concat_unique Back p2 p1 (* arguments reversed! *)
  else if is_uniquely_owned p2 o then
    concat_unique Front p1 p2
  else
    concat_shared p1 p2 o

(* -------------------------------------------------------------------------- *)

(* Auxiliary functions, used within assertions only, inside [reach] (below).  *)

(* [weight_of_prefix p m i] computes the total weight of the elements of the
   schunk [p] up to index [i] excluded. *)

let weight_of_prefix p m (i : index) =
  (* [i = length p] is purposely allowed. *)
  assert (0 <= i && i <= length p);
  let prefix = View.restrict p.support p.view 0 i in
  View.fold_left (fun accu x -> accu + apply m x) 0 (p.support, prefix)

(* [validate p w m (weight, index)] checks that the weight index [weight] and
   the index [index] are consistent with one another, relative to the schunk
   [p]: that is, [weight] must be the sum of the weights of the elements whose
   index is less than [index]. It also checks that the weight index [w] falls
   within the element [x] designated by [weight] and [index]. These properties
   form the postcondition of [reach]. *)

(* Once assertions are erased, [validate] becomes an identity function. *)

let[@inline] validate p m (w : weight) ((weight, index) as pair) =
  assert (0 <= index && index < length p);
  assert (weight = weight_of_prefix p m index);
  assert (
    let x = View.get p.support p.view index in
    weight <= w && w < weight + apply m x
  );
  pair

(* -------------------------------------------------------------------------- *)

(* Translating a weight index to an index. *)

(* If [m] is the unit measure, then a weight index is an index, so this
   translation is the identity. *)

(* If [m] is not the unit measure, then we have no efficient way of performing
   this translation. We must scan the chunk linearly, stopping when the desired
   index is found. *)

exception Break

let[@specialise] reach_from (type a)
  (m : a measure) (p : a t) (pindex : index) (pwindex : weight) (w : weight)
: weight * index =
  (* We might like to assert that [p] is valid, but we are missing the
     parameter [o] in the call [check m o p], and we cannot use a dummy owner,
     as that could violate the dynamic checks in [is_uniquely_owned]. *)
  assert (0 <= w && w < p.weight);
  (* Check that [pindex] is a valid index. There is a little asymmetry here],
     as we allow [pindex] to lie between [0] and [length p] included, but do
     not allow [-1]. Allowing [length p] is convenient for callers. Allowing
     [-1] does not seem useful. *)
  assert (0 <= pindex && pindex <= length p);
  (* Check that [pwindex] and [pindex] are consistent with one another. *)
  assert (pwindex = weight_of_prefix p m pindex);
  (* We exploit the ability of testing whether [m] is the unit measure. *)
  match m with
  | MUnit ->
      w, w
  | MSWeight ->
      if pwindex <= w then begin
        (* Scan forward, starting at [pindex] included. *)
        (* Current index and current cumulative weight. *)
        let index, weight = ref pindex, ref pwindex in
        let range = View.restrict p.support p.view pindex (length p - pindex) in
        begin try
          View.iter Front (fun x ->
            let next_weight = !weight + x.weight (* or: [apply m x] *) in
            if w < next_weight then
              raise Break;
            weight := next_weight;
            index := !index + 1
          ) (p.support, range);
          (* Because we have required [w < p.weight], we expect to find
             an index less than [length p]. We cannot run off the end. *)
          assert false
        with Break ->
          (* Because we have required [w < p.weight], we expect to find
             an index less than [length p]. We cannot run off the end. *)
          assert (!index < length p)
        end;
        validate p m w (!weight, !index)
      end
      else begin
        assert (w < pwindex);
        (* Scan backwards, starting at [pindex] excluded. *)
        let range = View.restrict p.support p.view 0 pindex in
        (* Current index and current cumulative weight. *)
        let index, weight = ref pindex, ref pwindex in
        begin try
          View.iter Back (fun x ->
            index := !index - 1;
            weight := !weight - x.weight (* or: [apply m x] *);
            if !weight <= w then
              raise Break;
          ) (p.support, range);
          (* Because we have [0 <= w], we expect to find a nonnegative
             index. We cannot run off the left end. *)
          assert false
        with Break ->
          (* Because we have [0 <= w], we expect to find a nonnegative
             index. We cannot run off the left end. *)
          assert (0 <= !index)
        end;
        validate p m w (!weight, !index)
      end

(* [reach] is implemented using [reach_from]. A heuristic criterion is used to
   choose which side to start from, depending on whether [w] is closer to zero
   or to [p.weight]. *)

let[@inline] reach (type a) (m : a measure) (p : a t) (w : weight) =
  assert (0 <= w && w <= p.weight);
  (* When [m] is the unit measure, there is no need to scan, hence no need
     to decide where the scan should start. *)
  match m with
  | MUnit ->
      w, w
  | MSWeight ->
      let pindex, pwindex =
        if w < p.weight - w then
          0, 0
        else
          length p, p.weight
      in
      reach_from m p pindex pwindex w

(* Random access by weight. *)

(* [adjust_weight_index p w m] invokes [reach m p w] and uses the
   returned weight-of-the-left-prefix to adjust the weight-index [w]. Thus, it
   returns a pair of an adjusted weight-index [w] and an index [j] into the
   schunk [p]. *)

let[@inline] adjust_weight_index p w m =
  let weight, j = reach m p w in
  let w = w - weight in
  w, j

let[@inline] get_by_weight m p w =
  let w, j = adjust_weight_index p w m in
  let x = get p j in
  w, x

let update_by_weight m o f p w =
  let w, j = adjust_weight_index p w m in
  let x = get p j in
  (* let weight = apply m x in *)
  let x' = f x w in
  (* let weight' = apply m x' in
     assert (weight = weight'); *)
  let delta = 0 in
  set p j x' delta o

(* If we remove the hypothesis that [x] and [x'] must have the same weight,
   then [delta] should be defined as [weight' - weight]. Note that the weight
   of [x] must be measured before invoking [f], because [f] can have a side
   effect and change the weight of [x]. *)

(* -------------------------------------------------------------------------- *)

(* [three_way_split_unique] deals with the case where [p] is uniquely owned.
   The index [j] is the index of the element [x] where the split should take
   place. The view [view1] and weight [weight1] describe the elements that
   precede [x], while [view2] and [weight2] describe the elements that follow
   [x]. *)

(* The current implementation does not perform in-place updates, but one could
   do so in the future. Indeed, the support of [p] could be re-used either for
   [p1] or for [p2], depending on which is smaller. (We want to minimize the
   amount of data that is copied to a newly-allocated chunk.) The support of
   [p] must then be trimmed; this requires a new function [EChunk.trim c v],
   which reduces chunk [c] to view [v] and writes default values to the
   just-emptied slots if required. See code below. LATER *)

let[@inline] three_way_split_unique p o view1 weight1 x view2 weight2 =
  (* Allocate two uniquely-owned schunks for the two views. *)
  let p1 = sub p.support o view1 weight1
  and p2 = sub p.support o view2 weight2 in
  p1, x, p2

(* FOR FUTURE OPTIMIZATION OF ABOVE FUNCTION:
   STILL MISSING A TEST TO DECIDE WHICH SIDE TO KEEP AND WHICH SIDE TO COPY
  assert (is_aligned p);
  let n = length p in
  let p1 = sub p.support o view1 weight1 in
  let p2 = p in
  EChunk.trim p2.support view2;
  p2.view <- view2;
  p2.weight <- weight2;
  assert (length p1 = j && length p2 = n - j - 1);
  assert (is_aligned p1);
  assert (is_aligned p2);
  p1, x, p2
*)

(* [three_way_split_shared] deals with the case where [p] is shared. *)

let[@inline] three_way_split_shared p o view1 weight1 x view2 weight2 =
  let p1 = share p o view1 weight1
  and p2 = share p o view2 weight2 in
  p1, x, p2

let three_way_split p i m o =
  assert (0 <= i && i < weight p);
  let weight1, j = reach m p i in
  let view1, x, view2 = View.three_way_split p.support p.view j in
  assert (View.size view1 = j);
  assert (View.size view2 = length p - j - 1);
  let weight2 = p.weight - weight1 - apply m x in
  if is_uniquely_owned p o then
    three_way_split_unique p o view1 weight1 x view2 weight2
  else
    three_way_split_shared p o view1 weight1 x view2 weight2

(* -------------------------------------------------------------------------- *)

(* Take. *)

let[@inline] take_unique p o view1 weight1 j x =
  let p1 = sub p.support o view1 weight1 in
  assert (length p1 = j);
  assert (is_aligned p1);
  p1, x

let[@inline] take_shared p o view1 weight1 j x =
  let p1 = share p o view1 weight1 in
  assert (length p1 = j);
  p1, x

let take p i m o =
  assert (0 <= i && i < weight p);
  let weight1, j = reach m p i in
  let view1, x = View.take p.support p.view j in
  if is_uniquely_owned p o then
    take_unique p o view1 weight1 j x
  else
    take_shared p o view1 weight1 j x

(* -------------------------------------------------------------------------- *)

(* Drop. *)

let[@inline] drop_unique p o j x view2 weight2 =
  let p2 = sub p.support o view2 weight2 in
  assert (length p2 = length p - j - 1);
  assert (is_aligned p2);
  x, p2

let[@inline] drop_shared p o j x view2 weight2 =
  let p2 = share p o view2 weight2 in
  assert (length p2 = length p - j - 1);
  x, p2

let drop p i m o =
  assert (0 <= i && i < weight p);
  let weight1, j = reach m p i in
  let x, view2 = View.drop p.support p.view j in
  let weight2 = p.weight - weight1 - apply m x in
  if is_uniquely_owned p o then
    drop_unique p o j x view2 weight2
  else
    drop_shared p o j x view2 weight2

end
