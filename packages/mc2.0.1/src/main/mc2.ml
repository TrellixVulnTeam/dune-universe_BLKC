(*
MSAT is free software, using the Apache license, see file LICENSE
Copyright 2014 Guillaume Bury
Copyright 2014 Simon Cruanes
*)

open Mc2_core
open CCResult.Infix

module E = CCResult
module Fmt = CCFormat

type 'a or_error = ('a, string) E.t

let file = ref ""
let p_cnf = ref false
let p_dot_proof = ref ""
let p_proof_print = ref false
let p_model = ref false
let check = ref true
let time_limit = ref 300.
let size_limit = ref 1000_000_000.
let restarts = ref true
let gc = ref true
let p_stat = ref false
let p_gc_stat = ref false
let p_progress = ref false

module Dot = Mc2_backend.Dot.Make(Mc2_backend.Dot.Default)

let hyps = ref []

let check_model state =
  let check_clause c =
    let l =
      List.map
        (fun a ->
           Log.debugf 99
             (fun k -> k "Checking value of %a" Term.pp (Atom.term a));
           Solver.Sat_state.eval state a)
        c
    in
    List.exists (fun x -> x) l
  in
  let l = List.map check_clause !hyps in
  List.for_all (fun x -> x) l

(* Arguments parsing *)
let int_arg r arg =
  let l = String.length arg in
  let multiplier m =
    let arg1 = String.sub arg 0 (l-1) in
    r := m *. (float_of_string arg1)
  in
  if l = 0 then raise (Arg.Bad "bad numeric argument")
  else
    try
      match arg.[l-1] with
        | 'k' -> multiplier 1e3
        | 'M' -> multiplier 1e6
        | 'G' -> multiplier 1e9
        | 'T' -> multiplier 1e12
        | 's' -> multiplier 1.
        | 'm' -> multiplier 60.
        | 'h' -> multiplier 3600.
        | 'd' -> multiplier 86400.
        | '0'..'9' -> r := float_of_string arg
        | _ -> raise (Arg.Bad "bad numeric argument")
    with Failure _ -> raise (Arg.Bad "bad numeric argument")

let input_file = fun s -> file := s

let usage = "Usage : main [options] <file>"
let argspec = Arg.align [
    "-bt", Arg.Unit (fun () -> Printexc.record_backtrace true), " enable stack traces";
    "--cnf", Arg.Set p_cnf, " prints the cnf used.";
    "--check", Arg.Set check, " build, check and print the proof (if output is set), if unsat";
    "--no-check", Arg.Clear check, " inverse of -check";
    "--gc", Arg.Set gc, " enable garbage collection";
    "--no-gc", Arg.Clear gc, " disable garbage collection";
    "--restarts", Arg.Set restarts, " enable restarts";
    "--no-restarts", Arg.Clear restarts, " disable restarts";
    "--dot", Arg.Set_string p_dot_proof, "<file> if provided, print the dot proof in the given file";
    "--stat", Arg.Set p_stat, " print statistics";
    "--model", Arg.Set p_model, " print model";
    "--no-model", Arg.Clear p_model, " do not print model";
    "--gc-stat", Arg.Set p_gc_stat, " outputs statistics about the GC";
    "-p", Arg.Set p_progress, " print progress bar";
    "--no-p", Arg.Clear p_progress, " no progress bar";
    "--lra-alt", Arg.Int Mc2_lra.set_lra_alt, "<int> activates variants of eq analysis in LRA";
    "--size", Arg.String (int_arg size_limit), "<s>[kMGT] sets the size limit for the sat solver";
    "--time", Arg.String (int_arg time_limit), "<t>[smhd] sets the time limit for the sat solver";
    "-t", Arg.String (int_arg time_limit), " same as --time";
    "-d", Arg.Int Log.set_debug, "<lvl> sets the debug verbose level";
  ]

type syntax =
  | Dimacs
  | Smtlib

let syntax_of_file file =
  if CCString.suffix ~suf:".cnf" file then Dimacs
  else Smtlib

(* Limits alarm *)
let check_limits ~switch () =
  let t = Sys.time () in
  let heap_size = (Gc.quick_stat ()).Gc.heap_words in
  let s = float heap_size *. float Sys.word_size /. 8. in
  if t > !time_limit || s > !size_limit then (
    Util.Switch.activate switch;
  )

let main () =
  CCFormat.set_color_default true;
  (* Administrative duties *)
  Arg.parse argspec input_file usage;
  if !file = "" then (
    Arg.usage argspec usage;
    exit 2
  );
  let switch = Util.Switch.create() in
  let syn = syntax_of_file !file in
  Util.setup_gc ();
  let gc_alarm = Gc.create_alarm (check_limits ~switch) in
  let solver =
    let plugins = match syn with
      | Dimacs ->
        [ Mc2_dimacs.plugin;
        ]
      | Smtlib ->
        [ Mc2_propositional.plugin;
          Mc2_unin_sort.plugin;
          Mc2_uf.plugin;
          Mc2_lra.plugin;
        ]
    in
    Solver.create ~plugins ()
  in
  let dot_proof = if !p_dot_proof = "" then None else Some !p_dot_proof in
  let res = match syn with
    | Smtlib ->
      (* parse pb *)
      let module Process = Mc2_smtlib.Make(struct let solver = solver end) in
      Process.parse !file >>= fun input ->
      Process.typecheck input >>= fun input ->
      (* TODO: parse list of plugins on CLI *)
      (* process statements *)
      begin
        try
          E.fold_l
            (fun () st ->
               Process.process_stmt
                 ~gc:!gc ~restarts:!restarts ~pp_cnf:!p_cnf ~switch
                 ~time:!time_limit ~memory:!size_limit
                 ?dot_proof ~pp_model:!p_model ~check:!check ~progress:!p_progress
                 st)
            () input
        with Exit ->
          E.return()
      end
    | Dimacs ->
      Mc2_dimacs.parse (Solver.services solver) !file >>= fun pb ->
      Mc2_dimacs.process
        ~pp_model:!p_model ~gc:!gc ?dot_proof ~restarts:!restarts ~check:!check
        ~time:!time_limit ~memory:!size_limit ~progress:!p_progress ~switch
        solver pb
  in
  if !p_stat then (
    Format.printf "%a@." Solver.pp_stats solver;
  );
  if !p_gc_stat then (
    Printf.printf "(gc_stats\n%t)\n" Gc.print_stat;
  );
  Gc.delete_alarm gc_alarm;
  res

let () = match main() with
  | E.Ok () -> ()
  | E.Error msg ->
    print_endline msg;
    exit 1
  | exception Error.Error msg ->
    print_endline msg;
    exit 1
  | exception Solver.Out_of_time ->
    Format.printf "Timeout@.";
    exit 2
  | exception Solver.Out_of_space ->
    Format.printf "Spaceout@.";
    exit 3
