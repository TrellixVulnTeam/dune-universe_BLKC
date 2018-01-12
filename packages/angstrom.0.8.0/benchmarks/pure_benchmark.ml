module R = Result
open Core
open Core_bench

let read file =
  let open Unix in
  let size = Int64.to_int_exn (stat file).st_size in
  let buf  = String.create size in
  let rec loop pos len fd =
    let n = read ~pos ~len ~buf fd in
    if n > 0 then loop (pos + n) (len - n) fd
  in
  with_file ~mode:[O_RDONLY] file ~f:(fun fd ->
    loop 0 size fd);
  Bigstring.of_string buf
;;

let zero =
  let len = 65_536 in
  Bigstring.of_string (String.make len '\x00')
;;

let make_bench name parser contents =
  Bench.Test.create ~name (fun () ->
    match Angstrom.(parse_bigstring parser contents) with
    | R.Ok _ -> ()
    | R.Error err -> failwith err)

let make_endian name p        = make_bench name (Angstrom.skip_many p)   zero
let make_json   name contents = make_bench name RFC7159.json             contents
let make_http   name contents = make_bench name RFC2616.request          contents

(* For input files involving trailing numbers, .e.g, [http-requests.txt.100],
 * go into the [benchmarks/data] directory and use the [replicate] script to
 * generate the file, i.e.,
 *
 *   [./replicate http-requests.txt 100]
 *
 *)
let main () =
  let twitter1    = read "benchmarks/data/twitter1.json" in
  let twitter10   = read "benchmarks/data/twitter10.json" in
  let twitter20   = read "benchmarks/data/twitter20.json" in
  let twitter_big = read "benchmarks/data/twitter.json" in
  let http_get    = read "benchmarks/data/http-requests.txt.100" in
  let json =
    Bench.make_command [
      make_json "twitter1"    twitter1;
      make_json "twitter10"   twitter10;
      make_json "twitter20"   twitter20;
      make_json "twitter-big" twitter_big;
    ]
  in
  let endian =
    Bench.make_command [
      make_endian "int64 le" Angstrom.LE.int64;
      make_endian "int64 be" Angstrom.BE.int64;
    ]
  in
  let http =
    Bench.make_command [ make_http "http" http_get ] 
  in
  let numbers =
    Bench.make_command [ 
      Bench.Test.create ~name:"float" (fun () ->
        float_of_string "1.7242915150166418e+36");
      Bench.Test.create ~name:"int" (fun () ->
        int_of_string "172429151501664");
      Bench.Test.create ~name:"int-float" (fun () ->
        float_of_string "172429151501664");
    ]
  in
  Command.run
    (Command.group ~summary:"various angstrom benchmarks" 
      [ "json"   , json
      ; "endian" , endian
      ; "http"   , http 
      ; "numbers", numbers
    ])

let () = main ()