(** Definition of types {!Ast.t} and {!AstSet.t} constituting the
    Abstract Syntaxic Tree (AST)
*)

(*  Do you think this file is wierd, with this 'module rec' thing?
    This is because we want the type 'Ast.t' to be used in 'Set' and
    also we want 'Set' to be inside an 'Ast.t', I had to come up with
    this recursive (and quite confusing) module thing. I got
    the idea from http://stackoverflow.com/questions/8552589
    Notes:
    (1) This is a trick that allows me to avoid repeating the type
       definitions in sig .. end and in struct .. end (explained
       in above link)
    (2) I don't know why but Set.elt wouldn't be Ast.t... So
       I tried this and now it works...
*)

open Err

module rec Ast :
sig
  type var = string * t list option
  and t =
    | Touist_code      of t list
    (* [Touist_code] is what is produced by of {!Parse.parse}. *)
    | Int              of int
    | Float            of float
    | Bool             of bool
    | Var              of var
    | Set              of AstSet.t
    | Set_decl         of t list
    | Neg              of t
    | Add              of t * t
    | Sub              of t * t
    | Mul              of t * t
    | Div              of t * t
    | Mod              of t * t
    | Sqrt             of t
    | To_int           of t
    | To_float         of t
    | Abs              of t
    | Top
    | Bottom
    | Not              of t
    | And              of t * t
    | Or               of t * t
    | Xor              of t * t
    | Implies          of t * t
    | Equiv            of t * t
    | Equal            of t * t
    | Not_equal        of t * t
    | Lesser_than      of t * t
    | Lesser_or_equal  of t * t
    | Greater_than     of t * t
    | Greater_or_equal of t * t
    | Union            of t * t
    | Inter            of t * t
    | Diff             of t * t
    | Range            of t * t
    | Empty            of t
    | Card             of t
    | Subset           of t * t
    | Powerset         of t
    | In               of t * t
    | If               of t * t * t
    | Exact            of t * t
    | Atleast          of t * t
    | Atmost           of t * t
    | Bigand           of t list * t list * t option * t
    | Bigor            of t list * t list * t option * t
    | Let              of t * t * t
    | Affect           of t * t
    | UnexpProp        of string * t list option (* Unexp = unexpanded *)
    (** [UnexpProp] is a proposition that contains unexpanded variables; we
        cannot tranform [UnexpProp] into [Prop] before knowing what is the
        content of the variables. Examples: {v
            abcd(1,$d,$i,a)       <- not a full-string yet                   v}
    *)
    | Prop             of string
    (** [Prop] contains the actual proposition after the evaluation has been
        run.
        Example: if $d=foo and $i=123, then the [Prop] is: {v
            abcd(1,foo,123,a)     <- an actual string that represents an actual
                                    logical proposition                      v}
    *)
    | Loc              of t * Err.loc
    (** [Loc] is a clever (or ugly, you pick) way of keeping the locations in
        the text of the Ast.t elements.
        In parser.mly, each production rule gives its location in the original
        text; for example, instead of simply returning
        [Inter (x,y)] the parser will return
        [Loc (Inter (x,y), ($startpos,$endpos))].

        [Loc] is used in eval.ml when checking the types; it allows to give precise
        locations.
    *)
    | Paren of t
    (** [Paren] keeps track of the parenthesis in the AST in order to print latex *)
    | Exists           of t * t
    | Forall           of t * t
    | For              of t * t * t
    | NewlineAfter     of t
    | NewlineBefore    of t
end
and AstSet :
sig
  include Set.S with type elt = Ast.t

    (** Return the different ways to choose k elements among a set of n
        elements *)
    val combinations : int -> t -> elt list list

    (** Return a list of tuples. The first member is a combination of k
        elements in the set and the second member is the list of every other
        set elements not in the combination *)
    val exact: int -> t -> (elt list * elt list) list

    (** Actually an alias for the combinations function:
        combinations k set *)
    val atleast: int -> t -> elt list list

    (** Equivalent to:
        combinations (n-k) set, where n = card(set)  *)
    val atmost: int -> t -> elt list list
end
