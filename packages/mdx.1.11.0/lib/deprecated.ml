(*
 * Copyright (c) 2018 Thomas Gazagnaire <thomas@gazagnaire.org>
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

let warn ?replacement s ~since =
  let replacement =
    match replacement with
    | Some r -> Format.sprintf "Please use %s instead." r
    | None -> Format.sprintf "There is no replacement for this feature."
  in
  Format.eprintf
    "Warning: %s is deprecated since %s and will be removed in 2.0.0. %s\n%!" s
    since replacement

module Missing_double_semicolon = struct
  let missing_semicolon = ref false

  let check_toplevel : Toplevel.t -> unit =
   fun toplevel ->
    match List.rev toplevel.command with
    | cmd :: _ ->
        let ends_with_semi =
          cmd |> Astring.String.trim |> Astring.String.is_suffix ~affix:";;"
        in
        if not ends_with_semi then missing_semicolon := true
    | [] -> ()

  let check_block block = List.iter check_toplevel block

  let report ~filename =
    if !missing_semicolon then
      Format.eprintf
        "Warning: OCaml toplevel block without trailing ;; detected in file \
         '%s'.\n\
         Non-semicolon terminated phrases are deprecated.\n\
         MDX 2.0 will accept them as input but will output them with ;; \
         appended.\n\
         In MDX 3.0 support for toplevel blocks without ;; will be removed \
         completely.\n"
        filename
end
