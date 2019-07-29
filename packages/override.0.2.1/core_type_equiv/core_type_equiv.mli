open Migrate_parsetree.OCaml_407.Ast

val equal_loc :
    ('a -> 'a -> bool) -> 'a Location.loc -> 'a Location.loc -> bool

val equiv_core_type :
    (Parsetree.core_type -> Parsetree.core_type -> bool) ->
      Parsetree.core_type -> Parsetree.core_type -> bool