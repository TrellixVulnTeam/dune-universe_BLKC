open Plebeia.Internal
open Result
open Test_utils
open Cursor
open Node

module RS = Random.State

module Debug = Debug

(* We cannot compare with Dumb *)
  
let random_seg st = random_segment ~length:3 st

let random_segs st = 
  let n = RS.int st 4 + 1 in
  List.init n (fun _ -> random_seg st)
    
let random_value st = Value.of_string @@ string_of_int @@ RS.int st 30

let validate context n =
  default (Debug.validate_node context n) (fun e -> 
      to_file ~file:"invalid.dot" @@ Debug.dot_of_node n;
      prerr_endline "Saved the current node to invalid.dot";
      failwith e)

let string_of_segs segs =
  String.concat "/" (List.map Segment.to_string segs)

let check_root c =
  match c with
  | Cursor (Top, _, _) -> ()
  | _ -> xassert false

let choose_random_segs st c =
  let Cursor (_, n, context) = c in
  match Node.view context n with
  | Internal _ | Extender _ | Leaf _ -> assert false
  | Bud (None, _, _) -> None (* unremovable *)
  | Bud (Some n, _, _) ->
      let rec choose_random_segs rev_segs rev_seg n =
        let v = Node.view context n in
        match v with
        | Leaf _ -> List.rev (List.rev rev_seg :: rev_segs)
        | Bud (None, _, _) -> List.rev (List.rev rev_seg :: rev_segs)
        | Bud (Some n, _, _) ->
            let rev_segs = List.rev rev_seg :: rev_segs in
            if RS.int st 2 = 0 then List.rev rev_segs
            else choose_random_segs rev_segs [] n
        | Internal (n1, n2, _, _) ->
            if RS.int st 2 = 0 then 
              let rev_seg = Segment.Left :: rev_seg in
              choose_random_segs rev_segs rev_seg n1
            else
              let rev_seg = Segment.Right :: rev_seg in
              choose_random_segs rev_segs rev_seg n2
        | Extender (seg, n, _, _) ->
            let rev_seg = List.rev_append (Segment.to_sides seg) rev_seg in
            choose_random_segs rev_segs rev_seg n
      in
      Some (List.map Segment.of_sides @@ choose_random_segs [] [] n)

let do_random st sz c =
  let rev_ops = ref [] in
  let add_op o = rev_ops := o :: !rev_ops in
  let rec f c i =
    if i = sz then c
    else 
      let c = 
        let rec get_op () = match RS.int st 8 with
          | 0 -> `Insert (random_segs st, random_value st)
          | 1 -> `Upsert (random_segs st, random_value st)
          | 2 -> `Subtree (random_segs st)
          | 3 -> `Commit
          | 4 -> 
              begin match choose_random_segs st c with
                | None -> get_op ()
                | Some segs -> 
                    let segs' = random_segs st in
                    `Copy (segs, segs')
              end
          | _ -> 
              match choose_random_segs st c with
              | None -> get_op ()
              | Some segs -> `Delete segs
        in
        let op = get_op () in
        match op with
        | `Insert (segs, v) ->
            (* Format.eprintf "Insert at %s@." @@ string_of_segs segs; *)
            begin match Deep.insert c segs v with
              | Ok c ->
                  add_op op;
                  check_root c;
                  c
              | Error _ -> c
            end
        | `Upsert (segs, v) ->
            (* Format.eprintf "Upsert at %s@." @@ string_of_segs segs; *)
            begin match Deep.upsert c segs v with
              | Ok c ->
                  add_op op;
                  check_root c;
                  c
              | Error _ -> c
            end
        | `Subtree segs ->
            (* Format.eprintf "Create_subtree at %s@." @@ string_of_segs segs; *)
            begin match Deep.create_subtree ~create_subtrees:true c segs with
              | Ok c -> 
                  add_op op;
                  check_root c;
                  c
              | Error _ -> c
            end
        | `Delete segs ->
            (* Format.eprintf "Delete at %s@." @@ string_of_segs segs; *)
            begin match 
                Deep.delete c segs
              with
              | Ok c -> 
                  add_op op;
                  check_root c;
                  c
              | Error _ -> c
            end
        | `Copy (segs, segs') ->
            begin match Deep.copy ~create_subtrees:true c segs segs' with
              | Ok c -> 
                  add_op op;
                  check_root c;
                  c
              | Error _ -> c
            end
        | `Commit ->
      (*
                  let Cursor(trail, _, _) = c in
                  let _segs = Cursor.segs_of_trail trail in
                  Format.eprintf "Commit and load: %s@." @@ string_of_segs segs;
      *)
                  let Cursor(_, _, context), i, _ = Cursor_storage.commit_top_cursor (Bud_cache.empty ()) c in
                  let v = Node_storage.load_node context i Not_Extender in
                  add_op op;
                  _Cursor (_Top, View v, context)
            in
            f c (i+1)
        in
        let c = f c 0 in
        (c, List.rev !rev_ops)

(* check of fold *)
let check_first_buds_and_leaves (Cursor (trail, n, context) as c) =
  assert (trail = _Top);
  let set1 = 
    match Node.view context n with
    | Bud (None, _, _) -> []
    | Bud (Some n, _, _) ->
        let rec aux st = function
          | [] -> st
          | (seg,n)::ns ->
              match Node.view context n with
              | Bud _ -> aux (`Bud (List.rev seg) :: st) ns
              | Leaf _ -> aux (`Leaf (List.rev seg) :: st) ns
              | Internal (n1, n2, _, _) ->
                  aux st ((Segment.Left::seg,n1)::(Segment.Right::seg,n2)::ns)
              | Extender (seg', n, _, _) ->
                  aux st ((List.rev_append (Segment.to_sides seg') seg,n)::ns)
        in
        List.sort compare @@ aux [] [([],n)] 
    | _ -> assert false
  in
  let set2 =
    match from_Ok @@ Cursor.go_below_bud c  with
    | None -> []
    | Some c ->
        List.sort compare
        @@ Cursor.fold ~init:[] c (fun acc c ->
            let _, v = Cursor.view c in
            match v with
            | Bud _ -> `Up, (`Bud (Segment.to_sides @@ local_seg_of_cursor c)::acc)
            | Leaf _ -> `Up, (`Leaf (Segment.to_sides @@ local_seg_of_cursor c)::acc)
            | _ -> `Continue, acc)
  in
  let print = function
    | `Bud seg -> Format.eprintf "B %s@." (Segment.to_string @@ Segment.of_sides seg)
    | `Leaf seg -> Format.eprintf "L %s@." (Segment.to_string @@ Segment.of_sides seg)
  in
  if set1 <> set2 then begin
    Format.eprintf "Set1@.";
    List.iter print set1;
    Format.eprintf "Set2@.";
    List.iter print set2;
    Debug.save_cursor_to_dot "folder.dot" c;
    assert false
  end 
    
(* check of fold *)
let check_nodes (Cursor (trail, n, context) as c) =
  assert (trail = _Top);
  let set1 = 
    let rec aux st = function
      | [] -> st
      | (seg,n)::ns ->
          match view context n with
          | Bud (None, _, _) -> aux (`Bud (List.rev seg)::st) ns
          | Bud (Some n1, _, _) -> aux (`Bud (List.rev seg)::st) ((seg,n1)::ns)
          | Leaf _ -> aux (`Leaf (List.rev seg)::st) ns
          | Internal (n1, n2, _, _) ->
              aux (`Internal (List.rev seg)::st) ((Segment.Left::seg,n1)::(Segment.Right::seg,n2)::ns)
          | Extender (seg', n1, _, _) ->
              aux (`Extender (List.rev seg)::st) ((List.rev_append (Segment.to_sides seg') seg,n1)::ns)
    in
    List.sort compare @@ aux [] [([],n)] 
  in
  let set2 =
    List.sort compare @@
    Cursor.fold ~init:[] c (fun acc c ->
        let _, v = Cursor.view c in
        let seg = List.concat @@ List.map Segment.to_sides @@ segs_of_cursor c in
        match v with
        | Bud _ -> `Continue, (`Bud seg::acc)
        | Leaf _ -> `Continue, (`Leaf seg::acc)
        | Internal _ -> `Continue, (`Internal seg::acc)
        | Extender _ -> `Continue, (`Extender seg::acc))
  in
  let print = function
    | `Bud seg -> Format.eprintf "B %s@." (Segment.to_string @@ Segment.of_sides seg)
    | `Leaf seg -> Format.eprintf "L %s@." (Segment.to_string @@ Segment.of_sides seg)
    | `Internal seg -> Format.eprintf "I %s@." (Segment.to_string @@ Segment.of_sides seg)
    | `Extender seg -> Format.eprintf "E %s@." (Segment.to_string @@ Segment.of_sides seg)
  in
  if set1 <> set2 then begin
    Format.eprintf "ERROR!@.";
    Format.eprintf "Set1@.";
    List.iter print set1;
    Format.eprintf "Set2@.";
    List.iter print set2;
    Debug.save_cursor_to_dot "folder.dot" c;
    assert false
  end 
    
let () = 
  let st = RS.make_self_init () in
  for i = 0 to 1000 do
    test_with_cursor @@ fun c ->
    let c, ops = do_random st 1000 c in

    (* check folder *)
    check_first_buds_and_leaves c;
    check_nodes c;

    if i mod 100 = 0 then begin
      Format.eprintf "%d done (%d ops)@." i
        (List.length ops);
      Debug.save_cursor_to_dot (Printf.sprintf "random%d.dot" i) c
    end
  done
