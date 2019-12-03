(* Copyright (C) 2019, Francois Berenger

   Yamanishi laboratory,
   Department of Bioscience and Bioinformatics,
   Faculty of Computer Science and Systems Engineering,
   Kyushu Institute of Technology,
   680-4 Kawazu, Iizuka, Fukuoka, 820-8502, Japan. *)

open Printf

include BatList

let to_string to_str l =
  let buff = Buffer.create 80 in
  Buffer.add_char buff '[';
  iteri (fun i x ->
      if i > 0 then Buffer.add_char buff ';';
      Buffer.add_string buff (to_str x);
    ) l;
  Buffer.add_char buff ']';
  Buffer.contents buff

let of_string of_str s =
  let s' = BatString.chop ~l:1 ~r:1 s in
  map of_str (BatString.nsplit s' ~by:";")

(* count elements satisfying 'p' *)
let filter_count p l =
  fold_left (fun acc x ->
      if p x then acc + 1
      else acc
    ) 0 l

let filter_counts p l =
  let ok_count = ref 0 in
  let ko_count = ref 0 in
  iter (fun x ->
      if p x then incr ok_count
      else incr ko_count
    ) l;
  (!ok_count, !ko_count)

(* only map 'f' on elements satisfying 'p' *)
let filter_map p f l =
  let res =
    fold_left (fun acc x ->
        if p x then (f x) :: acc
        else acc
      ) [] l in
  rev res

(* split a list into n parts (the last part might have
   a different number of elements) *)
let nparts n l =
  let len = length l in
  let res = ref [] in
  let curr = ref l in
  let m = int_of_float (BatFloat.ceil (float len /. float n)) in
  for _ = 1 to n - 1 do
    let xs, ys = takedrop m !curr in
    curr := ys;
    res := xs :: !res
  done;
  rev (!curr :: !res)

(* create folds of cross validation; each fold consists in (train, test) *)
let cv_folds n l =
  let test_sets = nparts n l in
  let rec loop acc prev curr =
    match curr with
    | [] -> acc
    | x :: xs ->
      let before_after = flatten (rev_append prev xs) in
      let prev' = x :: prev in
      let train_test = (before_after, x) in
      let acc' = train_test :: acc in
      loop acc' prev' xs in
  loop [] [] test_sets

(* dump list to file *)
let to_file (fn: string) (to_string: 'a -> string) (l: 'a list): unit =
  Utls.with_out_file fn (fun out ->
      iter (fun x -> fprintf out "%s\n" (to_string x)) l
    )

(* factorize code using parmap *)
let parmap ?init:(init = fun _ -> ()) ?pin_cores:(pin_cores = false)
    ?chunksize:(chunksize = 1)
    (ncores: int) (f: 'a -> 'b) (l: 'a list)
  : 'b list =
  if ncores <= 1 then map f l (* don't invoke parmap in vain *)
  else
    begin
      if not pin_cores then Parmap.disable_core_pinning ();
      Parmap.parmap ~ncores ~init ~chunksize f (Parmap.L l)
    end

(* factorize code using parmap *)
let parmapi ?init:(init = fun _ -> ()) ?pin_cores:(pin_cores = false)
    (ncores: int) (f: int -> 'a -> 'b) (l: 'a list): 'b list =
  if ncores <= 1 then mapi f l (* don't invoke parmap in vain *)
  else
    begin
      if not pin_cores then Parmap.disable_core_pinning ();
      Parmap.parmapi ~ncores ~init ~chunksize:1 f (Parmap.L l)
    end

let pariter ?init:(init = fun _ -> ())
    (ncores: int) (f: 'a -> unit) (l: 'a list): unit =
  if ncores <= 1 then iter f l (* don't invoke parmap in vain *)
  else
    (Parmap.disable_core_pinning ();
     Parmap.pariter ~ncores ~init ~chunksize:1 f (Parmap.L l))

let pariteri ?init:(init = fun _ -> ())
    (ncores: int) (f: int -> 'a -> unit) (l: 'a list): unit =
  if ncores <= 1 then iteri f l (* don't invoke parmap in vain *)
  else
    (Parmap.disable_core_pinning ();
     Parmap.pariteri ~ncores ~init ~chunksize:1 f (Parmap.L l))

(* parallel List.filter; elements satisfying p will be disordered *)
let parfilter (ncores: int) (p: 'a -> bool) (l: 'a list): 'a list =
  if ncores <= 1 then filter p l (* don't invoke parmap in vain *)
  else
    let () = Parmap.disable_core_pinning () in
    let f x =
      (p x, x) in
    let l' = Parmap.parmap ~ncores ~chunksize:1 f (Parmap.L l) in
    fold_left (fun acc (p_x, x) ->
        if p_x then x :: acc
        else acc
      ) [] l'

(* List.combine for 4 lists *)
let combine4 l1 l2 l3 l4 =
  let rec loop acc = function
    | ([], [], [], []) -> rev acc
    | (w :: ws, x :: xs, y :: ys, z :: zs) ->
      loop ((w, x, y, z) :: acc) (ws, xs, ys, zs)
    | _ -> raise (Invalid_argument "MyList.combine4: list lengths differ")
  in
  loop [] (l1, l2, l3, l4)

(* alias *)
let fold = fold_left

let really_take n l =
  let res = take n l in
  assert(length res = n);
  res

(* non reproducible randomization of a list *)
let random_shuffle l =
  let rng = BatRandom.State.make_self_init () in
  shuffle ~state:rng l

let rev_combine l1 l2 =
  let rec loop acc l r =
    match (l, r) with
    | ([], []) -> acc
    | (x :: xs, y :: ys) -> loop ((x, y) :: acc) xs ys
    | _ -> raise (Invalid_argument "MyList.rev_combine: list lengths differ")
  in
  loop [] l1 l2

(* filter using bit-mask [m] *)
let filter_mask m l =
  let rec loop acc = function
    | [] -> acc
    | (p, x) :: rest -> loop (if p then x :: acc else acc) rest
  in
  loop [] (rev_combine m l)

(* create a list of lists of [n] elements *)
let group_by n l =
  let rec loop acc = function
    | [] -> rev acc
    | l' ->
      let header, rest = takedrop n l' in
      loop (header :: acc) rest
  in
  loop [] l

let overlapping_pairs l =
  let rec loop acc = function
    | [_] | [] -> rev acc (* cannot make pair *)
    | x :: y :: rest ->
      let xy = rev_append x y in
      loop (xy :: acc) (y :: rest) in
  loop [] l

let rev_sort cmp l =
  sort (fun x y -> cmp y x) l

(* incr. sort by [cmp] then assignation of ranks *)
let rank_by cmp l =
  let sorted = sort cmp l in
  mapi (fun i x -> (i, x)) sorted

(* decr. sort by [cmp] then assignation of ranks *)
let rev_rank_by cmp l =
  let rev_sorted = rev_sort cmp l in
  mapi (fun i x -> (i, x)) rev_sorted

(* List.max with a comparison function *)
let maximum cmp l =
  let max_cmp x y =
    let res = cmp x y in
    if res >= 0 then x
    else y in
  match l with
  | [] -> failwith "MyList.maximum: empty list"
  | x :: xs -> fold_left max_cmp x xs

let numerate offset l =
  mapi (fun i x -> (i + offset, x)) l