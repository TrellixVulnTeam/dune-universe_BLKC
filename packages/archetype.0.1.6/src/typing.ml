(* -------------------------------------------------------------------- *)
open Ident
open Tools
open Location

module L  = Location
module PT = ParseTree
module M  = Ast

(* -------------------------------------------------------------------- *)
module Type : sig
  val as_container        : M.ptyp -> (M.ptyp * M.container) option
  val as_asset            : M.ptyp -> M.lident option
  val as_asset_collection : M.ptyp -> (M.lident * M.container) option
  val as_tuple            : M.ptyp -> (M.ptyp list) option

  val is_numeric : M.ptyp -> bool

  val equal      : M.ptyp -> M.ptyp -> bool
  val compatible : from_:M.ptyp -> to_:M.ptyp -> bool
end = struct
  let as_container = function M.Tcontainer (ty, c) -> Some (ty, c) | _ -> None
  let as_asset     = function M.Tasset     x       -> Some x       | _ -> None
  let as_tuple     = function M.Ttuple     ts      -> Some ts      | _ -> None

  let as_asset_collection = function
    | M.Tcontainer (M.Tasset asset, c) -> Some (asset, c)
    | _ -> None

  let is_numeric = function
    | M.Tbuiltin (M.VTint | M.VTrational) ->
      true

    | _ ->
      false

  let equal = ((=) : M.ptyp -> M.ptyp -> bool)

  let compatible ~(from_ : M.ptyp) ~(to_ : M.ptyp) =
    match from_, to_ with
    | _, _ when from_ = to_ ->
      true

    | M.Tbuiltin bfrom, M.Tbuiltin bto -> begin
        match bfrom, bto with
        | M.VTaddress, M.VTrole
        | M.VTint    , M.VTrational -> true

        | _, _ -> false
      end

    | _, _ ->
      false
end

(* -------------------------------------------------------------------- *)
type error_desc =
  | AssetExpected
  | AssetWithoutFields
  | BindingInExpr
  | CannotInferAnonRecord
  | CannotInferCollectionType
  | CollectionExpected
  | DivergentExpr
  | DuplicatedAssetName                of ident
  | DuplicatedCtorName                 of ident
  | DuplicatedFieldInAssetDecl         of ident
  | DuplicatedFieldInRecordLiteral     of ident
  | DuplicatedInitMarkForCtor
  | DuplicatedPKey
  | DuplicatedVarDecl                  of ident
  | AnonymousFieldInEffect
  | EmptyStateDecl
  | ExpressionExpected
  | FormulaExpected
  | IncompatibleTypes                  of M.ptyp * M.ptyp
  | InvalidActionDescription
  | InvalidActionExpression
  | InvalidArcheTypeDecl
  | InvalidAssetCollectionExpr
  | InvalidAssetExpression
  | InvalidCallByExpression
  | InvalidExpressionForEffect
  | InvalidExpression
  | InvalidFieldsCountInRecordLiteral
  | InvalidLValue
  | InvalidFormula
  | InvalidInstruction
  | InvalidNumberOfArguments           of int * int
  | InvalidRoleExpression
  | InvalidSecurityAction
  | InvalidSecurityRole
  | InvalidStateExpression
  | LetInElseInInstruction
  | MissingFieldInRecordLiteral        of ident
  | MixedAnonInRecordLiteral
  | MixedFieldNamesInRecordLiteral     of ident list
  | MoreThanOneInitState               of ident list
  | MultipleInitialMarker
  | MultipleMatchingOperator
  | MultipleStateDeclaration
  | NameIsAlreadyBound                 of ident
  | NoMatchingOperator
  | NoSuchMethod                       of ident
  | NoSuchSecurityPredicate            of ident
  | NonLoopLabel                       of ident
  | NotARole                           of ident
  | NumericExpressionExpected
  | OpInRecordLiteral
  | OrphanedLabel                      of ident
  | ReadOnlyGlobal                     of ident
  | SecurityInExpr
  | SpecOperatorInExpr
  | UnknownAction                      of ident
  | UnknownAsset                       of ident
  | UnknownField                       of ident * ident
  | UnknownFieldName                   of ident
  | UnknownLabel                       of ident
  | UnknownLocalOrVariable             of ident
  | UnknownProcedure                   of ident
  | UnknownState                       of ident
  | UnknownTypeName                    of ident
  | UnpureInFormula
  | VoidMethodInExpr
  | AssetPartitionnedby                of ident * ident list
[@@deriving show {with_path = false}]

type error = L.t * error_desc

let pp_error_desc fmt e =
  match e with
  | AssetExpected                      -> Format.fprintf fmt "Asset expected"
  | AssetWithoutFields                 -> Format.fprintf fmt "Asset without fields"
  | BindingInExpr                      -> Format.fprintf fmt "Binding in expression"
  | CannotInferAnonRecord              -> Format.fprintf fmt "Cannot infer a non record"
  | CannotInferCollectionType          -> Format.fprintf fmt "Cannot infer collection type"
  | CollectionExpected                 -> Format.fprintf fmt "Collection expected"
  | DivergentExpr                      -> Format.fprintf fmt "Divergent expression"
  | DuplicatedAssetName i              -> Format.fprintf fmt "Duplicated asset name: %a" pp_ident i
  | DuplicatedCtorName i               -> Format.fprintf fmt "Duplicated constructor name: %a" pp_ident i
  | DuplicatedFieldInAssetDecl i       -> Format.fprintf fmt "Duplicated field in asset declaration: %a" pp_ident i
  | DuplicatedFieldInRecordLiteral i   -> Format.fprintf fmt "Duplicated field in record literal: %a" pp_ident i
  | DuplicatedInitMarkForCtor          -> Format.fprintf fmt "Duplicated 'initialized by' section for asset"
  | DuplicatedPKey                     -> Format.fprintf fmt "Duplicated key"
  | DuplicatedVarDecl i                -> Format.fprintf fmt "Duplicated variable declaration: %a" pp_ident i
  | AnonymousFieldInEffect             -> Format.fprintf fmt "Anonymous field in effect"
  | EmptyStateDecl                     -> Format.fprintf fmt "Empty state declaration"
  | ExpressionExpected                 -> Format.fprintf fmt "Expression expected"
  | FormulaExpected                    -> Format.fprintf fmt "Formula expected"
  | IncompatibleTypes (t1, t2)         -> Format.fprintf fmt "Incompatible types: found '%a' but expected '%a'" Printer_ast.pp_ptyp t1 Printer_ast.pp_ptyp t2
  | InvalidActionDescription           -> Format.fprintf fmt "Invalid action description"
  | InvalidActionExpression            -> Format.fprintf fmt "Invalid action expression"
  | InvalidArcheTypeDecl               -> Format.fprintf fmt "Invalid Archetype declaration"
  | InvalidAssetCollectionExpr         -> Format.fprintf fmt "Invalid asset collection expression"
  | InvalidAssetExpression             -> Format.fprintf fmt "Invalid asset expression"
  | InvalidCallByExpression            -> Format.fprintf fmt "Invalid 'Calledby' expression"
  | InvalidExpressionForEffect         -> Format.fprintf fmt "Invalid expression for effect"
  | InvalidExpression                  -> Format.fprintf fmt "Invalid expression"
  | InvalidFieldsCountInRecordLiteral  -> Format.fprintf fmt "Invalid fields count in record literal"
  | InvalidLValue                      -> Format.fprintf fmt "Invalid value"
  | InvalidFormula                     -> Format.fprintf fmt "Invalid formula"
  | InvalidInstruction                 -> Format.fprintf fmt "Invalid instruction"
  | InvalidNumberOfArguments (n1, n2)  -> Format.fprintf fmt "Invalid number of arguments: found '%i', but expected '%i'" n1 n2
  | InvalidRoleExpression              -> Format.fprintf fmt "Invalid role expression"
  | InvalidSecurityAction              -> Format.fprintf fmt "Invalid security action"
  | InvalidSecurityRole                -> Format.fprintf fmt "Invalid security role"
  | InvalidStateExpression             -> Format.fprintf fmt "Invalid state expression"
  | LetInElseInInstruction             -> Format.fprintf fmt "Let In else in Instruction"
  | MissingFieldInRecordLiteral i      -> Format.fprintf fmt "Missing field in record literal: %a" pp_ident i
  | MixedAnonInRecordLiteral           -> Format.fprintf fmt "Mixed anonymous in record literal"
  | MixedFieldNamesInRecordLiteral l   -> Format.fprintf fmt "Mixed field names in record literal: %a" (Printer_tools.pp_list "," pp_ident) l
  | MoreThanOneInitState l             -> Format.fprintf fmt "More than one initial state: %a" (Printer_tools.pp_list ", " pp_ident) l
  | MultipleInitialMarker              -> Format.fprintf fmt "Multiple 'initial' marker"
  | MultipleMatchingOperator           -> Format.fprintf fmt "Mutliple matching operator"
  | MultipleStateDeclaration           -> Format.fprintf fmt "Multiple state declaration"
  | NameIsAlreadyBound i               -> Format.fprintf fmt "Name is already used: %a" pp_ident i
  | NoMatchingOperator                 -> Format.fprintf fmt "No matching operator"
  | NoSuchMethod i                     -> Format.fprintf fmt "No such method: %a" pp_ident i
  | NoSuchSecurityPredicate i          -> Format.fprintf fmt "No such security predicate: %a" pp_ident i
  | NonLoopLabel i                     -> Format.fprintf fmt "Not a loop lable: %a" pp_ident i
  | NotARole i                         -> Format.fprintf fmt "Not a role: %a" pp_ident i
  | NumericExpressionExpected          -> Format.fprintf fmt "Expecting numerical expression"
  | OpInRecordLiteral                  -> Format.fprintf fmt "Operation in record literal"
  | OrphanedLabel i                    -> Format.fprintf fmt "Label not used: %a" pp_ident i
  | ReadOnlyGlobal i                   -> Format.fprintf fmt "Global is read only: %a" pp_ident i
  | SecurityInExpr                     -> Format.fprintf fmt "Found securtiy predicate in expression"
  | SpecOperatorInExpr                 -> Format.fprintf fmt "Specification operator in expression"
  | UnknownAction i                    -> Format.fprintf fmt "Unknown action: %a" pp_ident i
  | UnknownAsset i                     -> Format.fprintf fmt "Unknown asset: %a" pp_ident i
  | UnknownField (i1, i2)              -> Format.fprintf fmt "Unknown field: asset %a does not have a field %a" pp_ident i1 pp_ident i2
  | UnknownFieldName i                 -> Format.fprintf fmt "Unknown field name: %a" pp_ident i
  | UnknownLabel i                     -> Format.fprintf fmt "Unknown label: %a" pp_ident i
  | UnknownLocalOrVariable i           -> Format.fprintf fmt "Unknown local or variable: %a" pp_ident i
  | UnknownProcedure i                 -> Format.fprintf fmt "Unknown procedure: %a" pp_ident i
  | UnknownState i                     -> Format.fprintf fmt "Unknown state: %a" pp_ident i
  | UnknownTypeName i                  -> Format.fprintf fmt "Unknown type: %a" pp_ident i
  | UnpureInFormula                    -> Format.fprintf fmt "Cannot use expression with side effect"
  | VoidMethodInExpr                   -> Format.fprintf fmt "Expecting arguments"
  | AssetPartitionnedby (i, l)         -> Format.fprintf fmt "Cannot access asset collection: asset %a is partitionned by field(s) (%a)" pp_ident i (Printer_tools.pp_list ", " pp_ident) l

(* -------------------------------------------------------------------- *)
type argtype = [`Type of M.type_ | `Effect of ident]

(* -------------------------------------------------------------------- *)
type procsig = {
  psl_sig  : argtype list;
  psl_ret  : M.ptyp;
}

(* -------------------------------------------------------------------- *)
type opsig = {
  osl_sig : M.ptyp list;
  osl_ret : M.ptyp;
}

(* -------------------------------------------------------------------- *)
let eqtypes =
  [ M.VTbool           ;
    M.VTint            ;
    M.VTrational       ;
    M.VTdate           ;
    M.VTduration       ;
    M.VTstring         ;
    M.VTaddress        ;
    M.VTrole           ;
    M.VTcurrency       ;
    M.VTkey            ]

let cmptypes =
  [ M.VTint            ;
    M.VTrational       ;
    M.VTdate           ;
    M.VTduration       ;
    M.VTstring         ;
    M.VTcurrency       ]

let grptypes =
  [ M.VTdate           ;
    M.VTduration       ;
    M.VTcurrency       ]

let rgtypes =
  [ M.VTint      ;
    M.VTrational ]

(* -------------------------------------------------------------------- *)
let cmpsigs : (PT.operator * (M.vtyp list * M.vtyp)) list =
  let ops  = [PT.Gt; PT.Ge; PT.Lt; PT.Le] in
  let sigs = List.map (fun ty -> ([ty; ty], M.VTbool)) cmptypes in
  List.mappdt (fun op sig_ -> (`Cmp op, sig_)) ops sigs

let opsigs =
  let eqsigs : (PT.operator * (M.vtyp list * M.vtyp)) list =
    let ops  = [PT.Equal; PT.Nequal] in
    let sigs = List.map (fun ty -> ([ty; ty], M.VTbool)) eqtypes in
    List.mappdt (fun op sig_ -> (`Cmp op, sig_)) ops sigs in

  let grptypes : (PT.operator * (M.vtyp list * M.vtyp)) list =
    let ops  =
      (List.map (fun x -> `Arith x) [PT.Plus ; PT.Minus])
      @ (List.map (fun x -> `Unary x) [PT.Uplus; PT.Uminus]) in
    let sigs = List.map (fun ty -> ([ty; ty], ty)) grptypes in
    List.mappdt (fun op sig_ -> (op, sig_)) ops sigs in

  let rgtypes : (PT.operator * (M.vtyp list * M.vtyp)) list =
    let ops  =
      (List.map (fun x -> `Arith x) [PT.Plus; PT.Minus; PT.Mult; PT.Div])
      @ (List.map (fun x -> `Unary x) [PT.Uplus; PT.Uminus]) in
    let sigs = List.map (fun ty -> ([ty; ty], ty)) rgtypes in
    List.mappdt (fun op sig_ -> (op, sig_)) ops sigs in

  let ariths : (PT.operator * (M.vtyp list * M.vtyp)) list =
    [`Arith PT.Modulo, ([M.VTint; M.VTint], M.VTint)] in

  let bools : (PT.operator * (M.vtyp list * M.vtyp)) list =
    let unas = List.map (fun x -> `Unary   x) [PT.Not] in
    let bins = List.map (fun x -> `Logical x) [PT.And; PT.Or; PT.Imply; PT.Equiv] in

    List.map (fun op -> (op, ([M.VTbool], M.VTbool))) unas
    @ List.map (fun op -> (op, ([M.VTbool; M.VTbool], M.VTbool))) bins in

  let others : (PT.operator * (M.vtyp list * M.vtyp)) list =
    [ `Arith PT.Plus, ([M.VTdate    ; M.VTduration      ], M.VTdate)             ;
      `Arith PT.Plus, ([M.VTint     ; M.VTduration      ], M.VTduration)         ;
      `Arith PT.Mult, ([M.VTrational; M.VTcurrency      ], M.VTcurrency       )  ] in

  eqsigs @ cmpsigs @ grptypes @ rgtypes @ ariths @ bools @ others

let opsigs =
  let doit (args, ret) =
    { osl_sig = List.map (fun x -> M.Tbuiltin x) args;
      osl_ret = M.Tbuiltin ret; } in
  List.map (snd_map doit) opsigs

(* -------------------------------------------------------------------- *)
type varfun = [
  | `Variable of PT.variable_decl
  | `Function of PT.s_function
]

type acttx = [
  | `Action     of PT.action_decl
  | `Transition of PT.transition_decl
]

type groups = {
  gr_archetypes  : (PT.lident * PT.exts)      loced list;
  gr_states      : PT.enum_decl               loced list;
  gr_enums       : (PT.lident * PT.enum_decl) loced list;
  gr_assets      : PT.asset_decl              loced list;
  gr_varfuns     : varfun                     loced list;
  gr_acttxs      : acttx                      loced list;
  gr_specs       : PT.specification           loced list;
  gr_secs        : PT.security                loced list;
}

(* -------------------------------------------------------------------- *)
(*
  (M.Cstate      , ([], `State))                     ;
  (M.Cnow        , ([], `Type M.vtdate))             ;
  (M.Ctransferred, ([], `Type (M.vtcurrency M.Tez))) ;
  (M.Ccaller     , ([], `Caller))                    ;
  (M.Cbalance    , ([], `Type (M.vtcurrency M.Tez))) ]
*)

let globals = [
  ("now"    ,     M.Cnow    , M.vtdate);
  ("balance",     M.Cbalance, M.vtcurrency);
  ("transferred", M.Ctransferred, M.vtcurrency);
  ("caller",      M.Ccaller,  M.vtaddress);
]

type method_ = {
  mth_name     : M.const;
  mth_purity   : [`Pure | `Effect];
  mth_totality : [`Total | `Partial];
  mth_sig      : mthtyp list * mthtyp option;
}

and mthtyp = [
  | `T        of M.ptyp
  | `The
  | `Pk
  | `Effect
  | `Asset
  | `SubColl
  | `Field
  | `Pred
  | `RExpr
  | `Ref      of int
]

let methods : (string * method_) list =
  let mk mth_name mth_purity mth_totality mth_sig =
    { mth_name; mth_purity; mth_totality; mth_sig; }
  in [
    ("isempty"     , mk M.Cisempty      `Pure   `Total   ([             ], Some (`T M.vtbool)));
    ("get"         , mk M.Cget          `Pure   `Partial ([`Pk          ], Some `The));
    ("add"         , mk M.Cadd          `Effect `Total   ([`The         ], None));
    ("addnofail"   , mk M.Caddnofail    `Effect `Total   ([`The         ], None));
    ("remove"      , mk M.Cremove       `Effect `Total   ([`Pk          ], None));
    ("removeorfail", mk M.Cremovenofail `Effect `Total   ([`Pk          ], None));
    ("removeif"    , mk M.Cremoveif     `Effect `Total   ([`Pred        ], None));
    ("update"      , mk M.Cupdate       `Effect `Total   ([`Pk; `Effect ], None));
    ("updatenofail", mk M.Cupdatenofail `Effect `Total   ([`Pk; `Effect ], None));
    ("clear"       , mk M.Cclear        `Effect `Total   ([             ], None));
    ("contains"    , mk M.Ccontains     `Pure   `Total   ([`Pk          ], Some (`T M.vtbool)));
    ("nth"         , mk M.Cnth          `Pure   `Partial ([`T M.vtint   ], Some (`Asset)));
    ("reverse"     , mk M.Creverse      `Effect `Total   ([             ], None));
    ("select"      , mk M.Cselect       `Pure   `Total   ([`Pred        ], Some (`SubColl)));
    ("sort"        , mk M.Csort         `Pure   `Total   ([`Field       ], Some (`SubColl)));
    ("count"       , mk M.Ccount        `Pure   `Total   ([             ], Some (`T M.vtint)));
    ("sum"         , mk M.Csum          `Pure   `Total   ([`RExpr       ], Some (`Ref 0)));
    ("max"         , mk M.Cmax          `Pure   `Partial ([`RExpr       ], Some (`Ref 0)));
    ("min"         , mk M.Cmin          `Pure   `Partial ([`RExpr       ], Some (`Ref 0)));
    ("subsetof"    , mk M.Csubsetof     `Pure   `Total   ([`SubColl     ], Some (`T M.vtbool)));
    ("head"        , mk M.Chead         `Pure   `Total   ([`T M.vtint   ], Some (`SubColl)));
    ("tail"        , mk M.Ctail         `Pure   `Total   ([`T M.vtint   ], Some (`SubColl)));
    ("before"      , mk M.Cbefore       `Pure   `Total   ([             ], Some (`SubColl)));
    ("unmoved"     , mk M.Cunmoved      `Pure   `Total   ([             ], Some (`SubColl)));
    ("added"       , mk M.Cadded        `Pure   `Total   ([             ], Some (`SubColl)));
    ("removed"     , mk M.Cremoved      `Pure   `Total   ([             ], Some (`SubColl)));
    ("iterated"    , mk M.Citerated     `Pure   `Total   ([             ], Some (`SubColl)));
    ("toiterate"   , mk M.Ctoiterate    `Pure   `Total   ([             ], Some (`SubColl)));
  ]

let methods = Mid.of_list methods

(* -------------------------------------------------------------------- *)

type security_pred_ = {
  sp_sig: sptyp list;
  (* sp_fun: PT.security_arg list -> M.security_node *)
}
and sptyp = [
  | `ActionDesc
  | `Role
  | `Action
]

let security_preds : (string * security_pred_) list =
  let mk sp_sig =
    { sp_sig }
  in [
    ("only_by_role",           mk [`ActionDesc; `Role]);
    ("only_in_action",         mk [`ActionDesc; `Action]);
    ("only_by_role_in_action", mk [`ActionDesc; `Role; `Action]);
    ("not_by_role",            mk [`ActionDesc; `Role]);
    ("not_in_action",          mk [`ActionDesc; `Action]);
    ("not_by_role_in_action",  mk [`ActionDesc; `Role; `Action]);
    ("transferred_by",         mk [`ActionDesc]);
    ("transferred_to",         mk [`ActionDesc]);
    ("no_storage_fail",        mk [`Action])
  ]

let security_preds = Mid.of_list security_preds

(* -------------------------------------------------------------------- *)

type assetdecl = {
  as_name   : M.lident;
  as_fields : (M.lident * M.ptyp) list;
  as_pk     : M.lident;
  as_sortk  : M.lident list;
  as_invs   : (M.lident option * M.pterm) list;
}

(* -------------------------------------------------------------------- *)
type vardecl = {
  vr_name   : M.lident;
  vr_type   : M.ptyp;
  vr_kind   : [`Constant | `Variable | `Ghost];
  vr_def    : (M.pterm * [`Inline | `Std]) option;
  vr_core   : M.const option;
}

(* -------------------------------------------------------------------- *)
type 'env ispecification = [
  | `Predicate     of M.lident * (M.lident * M.ptyp) list * M.pterm
  | `Definition    of M.lident * (M.lident * M.ptyp) option * M.pterm
  | `Lemma         of M.lident * M.pterm
  | `Theorem       of M.lident * M.pterm
  | `Variable      of M.lident * M.pterm option
  | `Assert        of M.lident * M.pterm * (M.lident * M.pterm list) list * M.lident list
  | `Effect        of 'env * M.instruction
  | `Postcondition of M.lident * M.pterm * (M.lident * M.pterm list) list * M.lident list
]

(* -------------------------------------------------------------------- *)
type 'env actiondecl = {
  ad_name   : M.lident;
  ad_args   : (M.lident * M.ptyp) list;
  ad_callby : M.lident list;
  ad_effect : M.instruction option;
  ad_reqs   : (M.lident option * M.pterm) list;
  ad_fais   : (M.lident option * M.pterm) list;
  ad_spec  : 'env ispecification list;
}

(* -------------------------------------------------------------------- *)
type transitiondecl = {
  td_name : M.lident;
}

(* -------------------------------------------------------------------- *)
type statedecl = {
  sd_ctors : (M.lident * M.pterm list) list;
  sd_init  : ident;
}

(* -------------------------------------------------------------------- *)
let pterm_arg_as_pterm = function M.AExpr e -> Some e | _ -> None

(* -------------------------------------------------------------------- *)
let procsig_of_operator (_op : PT.operator) : procsig =
  assert false

(* -------------------------------------------------------------------- *)
let core_types = [
  ("string"   , M.vtstring         );
  ("int"      , M.vtint            );
  ("rational" , M.vtrational       );
  ("bool"     , M.vtbool           );
  ("role"     , M.vtrole           );
  ("address"  , M.vtaddress        );
  ("date"     , M.vtdate           );
  ("tez"      , M.vtcurrency       );
  ("duration" , M.vtduration       );
]

(* -------------------------------------------------------------------- *)
module Env : sig
  type t

  type label_kind = [`Plain | `Loop of ident]

  type entry = [
    | `Label      of t * label_kind
    | `State      of statedecl
    | `Type       of M.ptyp
    | `Local      of M.ptyp
    | `Global     of vardecl
    | `Proc       of procsig
    | `Asset      of assetdecl
    | `Action     of t actiondecl
    | `Transition of transitiondecl
    | `Field      of ident
  ]

  type ecallback = error -> unit

  val create     : ecallback -> t
  val emit_error : t -> error -> unit
  val name_free  : t -> ident -> bool
  val lookup     : t -> ident -> entry option
  val open_      : t -> t
  val close      : t -> t
  val inscope    : t -> (t -> t * 'a) -> t * 'a

  module Label : sig
    val lookup : t -> ident -> (t * label_kind) option
    val get    : t -> ident -> t * label_kind
    val exists : t -> ident -> bool
    val push   : t -> ident * label_kind -> t
  end

  module Type : sig
    val lookup : t -> ident -> M.ptyp option
    val get    : t -> ident -> M.ptyp
    val exists : t -> ident -> bool
    val push   : t -> (ident * M.ptyp) -> t
  end

  module Local : sig
    val lookup : t -> ident -> (ident * M.ptyp) option
    val get    : t -> ident -> (ident * M.ptyp)
    val exists : t -> ident -> bool
    val push   : t -> ident * M.ptyp -> t
  end

  module Var : sig
    val lookup : t -> ident -> vardecl option
    val get    : t -> ident -> vardecl
    val exists : t -> ident -> bool
    val push   : t -> vardecl -> t
  end

  module Proc : sig
    val lookup : t -> ident -> procsig option
    val get    : t -> ident -> procsig
    val exists : t -> ident -> bool
  end

  module State : sig
    val byname : t -> ident -> ident option
    val push   : t -> statedecl -> t
  end

  module Asset : sig
    val lookup  : t -> ident -> assetdecl option
    val get     : t -> ident -> assetdecl
    val exists  : t -> ident -> bool
    val byfield : t -> ident -> (assetdecl * M.ptyp) option
    val push    : t -> assetdecl -> t
  end

  module Action : sig
    val lookup  : t -> ident -> t actiondecl option
    val get     : t -> ident -> t actiondecl
    val exists  : t -> ident -> bool
    val push    : t -> t actiondecl -> t
  end

  module Transition : sig
    val lookup  : t -> ident -> transitiondecl option
    val get     : t -> ident -> transitiondecl
    val exists  : t -> ident -> bool
    val push    : t -> transitiondecl -> t
  end
end = struct
  type ecallback = error -> unit

  type label_kind = [`Plain | `Loop of ident]

  type entry = [
    | `Label      of t * label_kind
    | `State      of statedecl
    | `Type       of M.ptyp
    | `Local      of M.ptyp
    | `Global     of vardecl
    | `Proc       of procsig
    | `Asset      of assetdecl
    | `Action     of t actiondecl
    | `Transition of transitiondecl
    | `Field      of ident
  ]

  and t = {
    env_error    : ecallback;
    env_bindings : entry Mid.t;
    env_locals   : Sid.t;
    env_scopes   : Sid.t list;
  }

  let create ecallback : t =
    { env_error    = ecallback;
      env_bindings = Mid.empty;
      env_locals   = Sid.empty;
      env_scopes   = []; }

  let emit_error (env : t) (e : error) =
    env.env_error e

  let name_free (env : t) (x : ident) =
    not (Mid.mem x env.env_bindings)

  let lookup (env : t) (name : ident) : entry option =
    Mid.find_opt name env.env_bindings

  let lookup_gen (proj : entry -> 'a option) (env : t) (name : ident) : 'a option =
    Option.bind proj (lookup env name)

  let push (env : t) (name : ident) (entry : entry) =
    let env = { env with env_bindings = Mid.add name entry env.env_bindings } in

    match entry with
    | `Local x -> { env with env_locals = Sid.add name env.env_locals }
    | _        -> env

  let open_ (env : t) =
    { env with
      env_locals = Sid.empty;
      env_scopes = env.env_locals :: env.env_scopes; }

  let close (env : t) =
    let lc, sc =
      match env.env_scopes with lc :: sc -> lc, sc | _ -> assert false in

    let bds =
      Sid.fold
        (fun x bds -> Mid.remove x bds) env.env_locals env.env_bindings in

    { env with env_bindings = bds; env_locals = lc; env_scopes = sc; }

  let inscope (env : t) (f : t -> t * 'a) =
    let env, aout = f (open_ env) in (close env, aout)

  module Label = struct
    let proj (entry : entry) =
      match entry with
      | `Label x    -> Some x
      | _           -> None

    let lookup (env : t) (name : ident) =
      lookup_gen proj env name

    let exists (env : t) (name : ident) =
      Option.is_some (lookup env name)

    let get (env : t) (name : ident) =
      Option.get (lookup env name)

    let push (env : t) ((name, kind) : ident * label_kind) =
      push env name (`Label (env, kind))
  end

  module Type = struct
    let proj (entry : entry) =
      match entry with
      | `Type  x    -> Some x
      | `Asset decl -> Some (M.Tasset decl.as_name)
      | _           -> None

    let lookup (env : t) (name : ident) =
      lookup_gen proj env name

    let exists (env : t) (name : ident) =
      Option.is_some (lookup env name)

    let get (env : t) (name : ident) =
      Option.get (lookup env name)

    let push (env : t) ((name, ty) : ident * M.ptyp) =
      push env name (`Type ty)
  end

  module State = struct
    let byname (env : t) (name : ident) =
      match Mid.find_opt name env.env_bindings with
      | Some (`State _) -> Some name
      | _ -> None

    let push (env : t) (decl : statedecl) =
      List.fold_left
        (fun env ({ pldesc = name }, _) -> (push env name (`State decl)))
        env decl.sd_ctors
  end

  module Local = struct
    let proj = function `Local x -> Some x | _ -> None

    let lookup (env : t) (name : ident) =
      Option.map (fun ty -> (name, ty)) (lookup_gen proj env name)

    let exists (env : t) (name : ident) =
      Option.is_some (lookup env name)

    let get (env : t) (name : ident) =
      Option.get (lookup env name)

    let push (env : t) ((x, ty) : ident * M.ptyp) =
      push env x (`Local ty)
  end

  module Var = struct
    let proj = function
      | `Global x ->
        Some x

      | `Asset  a ->
        Some { vr_name = a.as_name;
               vr_type = M.Tcontainer (M.Tasset a.as_name, M.Collection);
               vr_kind = `Constant;
               vr_core = None;
               vr_def  = None; }

      | _ -> None

    let lookup (env : t) (name : ident) =
      lookup_gen proj env name

    let exists (env : t) (name : ident) =
      Option.is_some (lookup env name)

    let get (env : t) (name : ident) =
      Option.get (lookup env name)

    let push (env : t) (decl : vardecl) =
      push env (unloc decl.vr_name) (`Global decl)
  end

  module Proc = struct
    let proj = function `Proc x -> Some x | _ -> None

    let lookup (env : t) (name : ident) =
      lookup_gen proj env name

    let exists (env : t) (name : ident) =
      Option.is_some (lookup env name)

    let get (env : t) (name : ident) =
      Option.get (lookup env name)
  end

  module Asset = struct
    let proj = function `Asset x -> Some x | _ -> None

    let lookup (env : t) (name : ident) =
      lookup_gen proj env name

    let exists (env : t) (name : ident) =
      Option.is_some (lookup env name)

    let get (env : t) (name : ident) =
      Option.get (lookup env name)

    let byfield (env : t) (fname : ident) =
      Option.bind
        (function
          | `Field nm ->
            let decl  = get env nm in
            let field = List.Exn.assoc_map unloc fname decl.as_fields in
            Some (decl, Option.get field)
          | _ -> None)
        (Mid.find_opt fname env.env_bindings)

    let push (env : t) ({ as_name = nm } as decl : assetdecl) : t =
      let env = push env (unloc nm) (`Asset decl) in
      List.fold_left
        (fun env (x, _) -> push env (unloc x) (`Field (unloc nm)))
        env decl.as_fields
  end

  module Action = struct
    let proj = function `Action x -> Some x | _ -> None

    let lookup (env : t) (name : ident) =
      lookup_gen proj env name

    let exists (env : t) (name : ident) =
      Option.is_some (lookup env name)

    let get (env : t) (name : ident) =
      Option.get (lookup env name)

    let push (env : t) (act : t actiondecl) =
      push env (unloc act.ad_name) (`Action act)
  end

  module Transition = struct
    let proj = function `Transition x -> Some x | _ -> None

    let lookup (env : t) (name : ident) =
      lookup_gen proj env name

    let exists (env : t) (name : ident) =
      Option.is_some (lookup env name)

    let get (env : t) (name : ident) =
      Option.get (lookup env name)

    let push (env : t) (td : transitiondecl) =
      push env (unloc td.td_name) (`Transition td)
  end
end

type env = Env.t

let empty : env =
  let cb (lc, error) =
    let str : string = Format.asprintf "%a@." pp_error_desc error in
    let pos : Position.t list = [location_to_position lc] in
    Error.error_alert pos str (fun _ -> ());

    Format.eprintf "%s: %a@."
      (Location.tostring lc) pp_error_desc error in

  let env = Env.create cb in

  let env =
    List.fold_left
      (fun env (name, ty) -> Env.Type.push env (name, ty))
      env core_types in

  let env =
    let mk vr_name vr_type vr_core =
      let def = M.Pconst vr_core in
      let def = M.{ node = def; type_ = Some vr_type; label = None; loc = L.dummy } in

      { vr_name; vr_type; vr_core = Some vr_core;
        vr_def = Some (def, `Inline); vr_kind = `Constant
      } in

    List.fold_left
      (fun env (name, const, ty) ->
         Env.Var.push env (mk (mkloc L.dummy name) ty const))
      env globals in

  env

(* -------------------------------------------------------------------- *)
let check_and_emit_name_free (env : env) (x : M.lident) =
  let free = Env.name_free env (unloc x) in
  if not free then
    Env.emit_error env (loc x, NameIsAlreadyBound (unloc x));
  free

(* -------------------------------------------------------------------- *)
let for_container (_ : env) = function
  | PT.Collection-> M.Collection
  | PT.Partition -> M.Partition

(* -------------------------------------------------------------------- *)
let for_assignment_operator = function
  | PT.ValueAssign  -> M.ValueAssign
  | PT.PlusAssign   -> M.PlusAssign
  | PT.MinusAssign  -> M.MinusAssign
  | PT.MultAssign   -> M.MultAssign
  | PT.DivAssign    -> M.DivAssign
  | PT.AndAssign    -> M.AndAssign
  | PT.OrAssign     -> M.OrAssign

(* -------------------------------------------------------------------- *)
let tt_logical_operator (op : PT.logical_operator) =
  match op with
  | And   -> M.And
  | Or    -> M.Or
  | Imply -> M.Imply
  | Equiv -> M.Equiv

(* -------------------------------------------------------------------- *)
let tt_arith_operator (op : PT.arithmetic_operator) =
  match op with
  | Plus   -> M.Plus
  | Minus  -> M.Minus
  | Mult   -> M.Mult
  | Div    -> M.Div
  | Modulo -> M.Modulo

(* -------------------------------------------------------------------- *)
let tt_cmp_operator (op : PT.comparison_operator) =
  match op with
  | Equal  -> M.Equal
  | Nequal -> M.Nequal
  | Gt     -> M.Gt
  | Ge     -> M.Ge
  | Lt     -> M.Lt
  | Le     -> M.Le

(* -------------------------------------------------------------------- *)
let get_asset_method (name : string) =
  None                          (* FIXME *)

(* -------------------------------------------------------------------- *)
exception InvalidType

let rec for_type_exn (env : env) (ty : PT.type_t) : M.ptyp =
  match unloc ty with
  | Tref x -> begin
      match Env.Type.lookup env (unloc x) with
      | None ->
        Env.emit_error env (loc x, UnknownTypeName (unloc x));
        raise InvalidType
      | Some ty -> ty
    end

  | Tasset x ->
    let decl = Env.Asset.lookup env (unloc x) in
    M.Tasset (Option.get_exn InvalidType decl).as_name

  | Tcontainer (ty, ctn) ->
    M.Tcontainer (for_type_exn env ty, for_container env ctn)

  | Ttuple tys ->
    M.Ttuple (List.map (for_type_exn env) tys)

  | Toption ty ->
    M.Toption (for_type_exn env ty)

let for_type (env : env) (ty : PT.type_t) : M.ptyp option =
  try Some (for_type_exn env ty) with InvalidType -> None

(* -------------------------------------------------------------------- *)
let for_literal (_env : env) (topv : PT.literal loced) : M.bval =
  let mk_sp type_ node = M.mk_sp ~loc:(loc topv) ~type_ node in

  match unloc topv with
  | Lbool b ->
    mk_sp M.vtbool (M.BVbool b)

  | Lnumber i ->
    mk_sp M.vtint (M.BVint i)

  | Lrational (n, d) ->
    mk_sp M.vtrational (M.BVrational (n, d))

  | Lstring s ->
    mk_sp M.vtstring (M.BVstring s)

  | Lmtz tz ->
    mk_sp (M.vtcurrency) (M.BVcurrency (M.Mtz, tz))

  | Ltz tz ->
    mk_sp (M.vtcurrency) (M.BVcurrency (M.Tz,  tz))

  | Laddress a ->
    mk_sp M.vtaddress (M.BVaddress a)

  | Lduration d ->
    mk_sp M.vtduration (M.BVduration (Core.string_to_duration d))

  | Ldate d ->
    mk_sp M.vtdate (M.BVdate d)

(* -------------------------------------------------------------------- *)
type emode_t = [`Expr | `Formula]

let rec for_xexpr (mode : emode_t) (env : env) ?(ety : M.ptyp option) (tope : PT.expr) =
  let for_xexpr = for_xexpr mode in

  let module E = struct exception Bailout end in

  let bailout = fun () -> raise E.Bailout in

  let mk_sp type_ node = M.mk_sp ~loc:(loc tope) ?type_ node in
  let dummy type_ : M.pterm = mk_sp type_ (M.Pvar (mkloc (loc tope) "<error>")) in

  let doit () =
    match unloc tope with
    | Eterm (None, None, x) -> begin
        match Env.lookup env (unloc x) with
        | Some (`Local xty) ->
          mk_sp (Some xty) (M.Pvar x)

        | Some (`Global decl) -> begin
            match decl.vr_def with
            | Some (body, `Inline) ->
              body
            | _ ->
              mk_sp (Some decl.vr_type) (M.Pvar x)
          end

        | Some (`Asset decl) ->
          let typ = M.Tcontainer ((M.Tasset decl.as_name), M.Collection) in
          mk_sp (Some typ) (M.Pvar x)

        | _ ->
          Env.emit_error env (loc x, UnknownLocalOrVariable (unloc x));
          bailout ()
      end

    | Eliteral v ->
      let v = for_literal env (mkloc (loc tope) v) in
      mk_sp v.M.type_ (M.Plit v)

    | Earray [] -> begin
        match ety with
        | Some (M.Tcontainer (_, _)) ->
          mk_sp ety (M.Parray [])

        | _ ->
          Env.emit_error env (loc tope, CannotInferCollectionType);
          bailout ()
      end

    | Earray (e :: es) -> begin
        let elty = Option.bind (Option.map fst |@ Type.as_container) ety in
        let e    = for_xexpr env ?ety:elty e in
        let elty = if Option.is_some e.M.type_ then e.M.type_ else elty in
        let es   = List.map (fun e -> for_xexpr env ?ety:elty e) es in

        match ety with
        | Some (M.Tcontainer (_, _)) ->
          mk_sp ety (M.Parray (e :: es))

        | _ ->
          Env.emit_error env (loc tope, CannotInferCollectionType);
          bailout ()
      end

    | Erecord fields -> begin
        let module E = struct
          type state = {
            hasupdate : bool;
            fields    : ident list;
            anon      : bool;
          }

          let state0 = {
            hasupdate = false; fields = []; anon = false;
          }
        end in

        let is_update = function
          | (None | Some (PT.ValueAssign, _)) -> false
          |  _ -> true in

        let infos = List.fold_left (fun state (fname, _) ->
            E.{ hasupdate = state.hasupdate || is_update fname;
                fields    = Option.fold
                    (fun names (_, name)-> unloc name :: names)
                    state.fields fname;
                anon      = state.anon || Option.is_none fname; })
            E.state0 fields in

        if infos.E.hasupdate then
          Env.emit_error env (loc tope, OpInRecordLiteral);

        if infos.E.anon && not (List.is_empty (infos.E.fields)) then begin
          Env.emit_error env (loc tope, MixedAnonInRecordLiteral);
          bailout ()
        end;

        if infos.E.anon || List.is_empty fields then
          match Option.map Type.as_asset ety with
          | None | Some None ->
            Env.emit_error env (loc tope, CannotInferAnonRecord);
            bailout ()

          | Some (Some asset) ->
            let asset = Env.Asset.get env (unloc asset) in
            let ne, ng = List.length fields, List.length asset.as_fields in

            if ne <> ng then begin
              Env.emit_error env (loc tope, InvalidFieldsCountInRecordLiteral);
              bailout ()
            end;

            let fields =
              List.map2 (fun (_, fe) (_, fty) ->
                  for_xexpr env ~ety:fty fe
                ) fields asset.as_fields;
            in mk_sp ety (M.Precord fields)

        else begin
          let fmap =
            List.fold_left (fun fmap (fname, e) ->
                let fname = unloc (snd (Option.get fname)) in

                Mid.update fname (function
                    | None -> begin
                        let asset = Env.Asset.byfield env fname in
                        if Option.is_none asset then begin
                          let err = UnknownFieldName fname in
                          Env.emit_error env (loc tope, err)
                        end; Some (asset, [e])
                      end

                    | Some (asset, es) ->
                      if List.length es = 1 then begin
                        let err = DuplicatedFieldInRecordLiteral fname in
                        Env.emit_error env (loc tope, err)
                      end; Some (asset, e :: es)) fmap
              ) Mid.empty fields
          in

          let assets =
            List.undup id (Mid.fold (fun _ (asset, _) assets ->
                Option.fold
                  (fun assets (asset, _) -> asset :: assets)
                  assets asset
              ) fmap []) in

          let assets = List.sort Stdlib.compare assets in

          let fields =
            Mid.map (fun (asset, es) ->
                let aty = Option.map snd asset in
                List.map (fun e -> for_xexpr env ?ety:aty e) es
              ) fmap in

          let record =
            match assets with
            | [] ->
              bailout ()

            | _ :: _ :: _ ->
              let err =
                MixedFieldNamesInRecordLiteral
                  (List.map (fun x -> unloc x.as_name) assets)
              in Env.emit_error env (loc tope, err); bailout ()

            | [asset] ->
              let fields =
                List.map (fun ({ pldesc = fname }, ftype) ->
                    match Mid.find_opt fname fields with
                    | None ->
                      let err = MissingFieldInRecordLiteral fname in
                      Env.emit_error env (loc tope, err); dummy (Some ftype)
                    | Some thisf ->
                      List.hd (List.rev thisf))
                  asset.as_fields
              in mk_sp (Some (M.Tasset asset.as_name)) (M.Precord fields)

          in record
        end
      end

    | Etuple es -> begin
        let etys =
          match Option.bind Type.as_tuple ety with
          | Some etys when List.length etys = List.length es ->
            List.map Option.some etys
          | _ ->
            List.make (fun _ -> None) (List.length es) in

        let es = List.map2 (fun ety e -> for_xexpr env ?ety e) etys es in
        let ty = Option.get_all (List.map (fun x -> x.M.type_) es) in
        let ty = Option.map (fun x -> M.Ttuple x) ty in

        mk_sp ty (M.Ptuple es)
      end

    | Edot (pe, x) -> begin
        if Mid.mem (unloc x) methods then
          for_xexpr env ?ety (mkloc (loc tope) (PT.Emethod (pe, x, [])))
        else

          let e = for_xexpr env pe in

          match Option.map Type.as_asset e.M.type_ with
          | None ->
            bailout ()

          | Some None ->
            Env.emit_error env (loc pe, AssetExpected);
            bailout ()

          | Some (Some asset) -> begin
              let asset = Env.Asset.get env (unloc asset) in

              match List.Exn.assoc_map unloc (unloc x) asset.as_fields with
              | None ->
                let err = UnknownField (unloc asset.as_name, unloc x) in
                Env.emit_error env (loc x, err); bailout ()

              | Some fty ->
                mk_sp (Some fty) (M.Pdot (e, x))
            end
      end

    | Emulticomp (e, l) ->
      let e = for_xexpr env e in
      let l = List.map (snd_map (for_xexpr env)) l in

      let _, aout =
        List.fold_left_map (fun e ({ pldesc = op }, e') ->
            match e.M.type_, e'.M.type_ with
            | Some ty, Some ty' ->
              let filter (sig_ : opsig) =
                if 2 <> List.length sig_.osl_sig then false else
                  List.for_all2 Type.equal [ty; ty'] sig_.osl_sig in

              let aout =
                match List.filter filter (List.assoc_all (`Cmp op) opsigs) with
                | [] ->
                  Env.emit_error env (loc tope, NoMatchingOperator);
                  None

                | _::_::_ ->
                  Env.emit_error env (loc tope, MultipleMatchingOperator);
                  None

                | [sig_] ->
                  Some (mk_sp (Some sig_.osl_ret) (M.Pcomp (tt_cmp_operator op, e, e')))

              in (e', aout)

            | _, _ ->
              e', None)
          e l in

      begin match List.pmap (fun x -> x) aout with
        | [] ->
          let lit = M.{ node  = M.BVbool true;
                        type_ = Some M.vtbool;
                        loc   = loc tope;
                        label = None; } in
          mk_sp (Some M.vtbool) (M.Plit lit)

        | e :: es ->
          List.fold_left (fun e e' ->
              (mk_sp (Some M.vtbool) (M.Plogical (tt_logical_operator And, e, e'))))
            e es
      end

    | Eapp (Foperator { pldesc = op }, args) -> begin
        let args = List.map (for_xexpr env) args in
        let na   = List.length args in

        if List.exists (fun arg -> Option.is_none arg.M.type_) args then
          bailout ();

        let filter (sig_ : opsig) =
          if na <> List.length sig_.osl_sig then false else

            List.for_all2
              (fun arg ty -> Type.equal (Option.get arg.M.type_) ty) (* FIXME *)
              args sig_.osl_sig in

        let sig_ =
          match List.filter filter (List.assoc_all op opsigs) with
          | [] ->
            Env.emit_error env (loc tope, NoMatchingOperator);
            bailout ()

          | _::_::_ ->
            Env.emit_error env (loc tope, MultipleMatchingOperator);
            bailout ()

          | [sig_] ->
            sig_ in

        let aout =
          match op with
          | `Logical op ->
            let a1, a2 = Option.get (List.as_seq2 args) in
            M.Plogical (tt_logical_operator op, a1, a2)

          | `Unary op -> begin
              let a1 = Option.get (List.as_seq1 args) in

              match
                match op with
                | PT.Not    -> `Not
                | PT.Uplus  -> `UArith (M.Uplus)
                | PT.Uminus -> `UArith (M.Uminus)
              with
              | `Not ->
                M.Pnot a1

              | `UArith op ->
                M.Puarith (op, a1)
            end

          | `Arith op ->
            let a1, a2 = Option.get (List.as_seq2 args) in
            M.Parith (tt_arith_operator op, a1, a2)

          | `Cmp op ->
            let a1, a2 = Option.get (List.as_seq2 args) in
            M.Pcomp (tt_cmp_operator op, a1, a2)

        in mk_sp (Some (sig_.osl_ret)) aout
      end

    | Emethod (the, m, args) -> begin
        let infos = for_gen_method_call mode env (loc tope) (the, m, args) in
        let the, asset, method_, args, amap = Option.get_fdfl bailout infos in

        let type_of_mthtype = function
          | `T typ   -> Some typ
          | `The     -> Some (M.Tasset asset.as_name)
          | `SubColl -> Some (M.Tcontainer (M.Tasset asset.as_name, M.Collection))
          | `Ref i   -> Some (Mint.find i amap)
          | _        -> assert false
        in

        if Option.is_none (snd method_.mth_sig) then begin
          Env.emit_error env (loc tope, VoidMethodInExpr)
        end;

        begin match method_.mth_purity, mode with
          | `Effect, `Formula ->
            Env.emit_error env (loc tope, UnpureInFormula)
          | _, _ ->
            () end;

        let rty = Option.bind type_of_mthtype (snd method_.mth_sig) in
        let rty =
          match method_.mth_totality, mode with
          | `Partial, `Formula ->
            rty (* Option.map (fun x -> M.Toption x) rty *)
          | _, _ ->
            rty in

        mk_sp rty (M.Pcall (Some the, M.Cconst method_.mth_name, args))
      end

    | Eif (c, et, Some ef) ->
      let c    = for_xexpr env ~ety:M.vtbool c in
      let et   = for_xexpr env et in
      let ef   = for_xexpr env ?ety:et.type_ ef in
      let aout = mk_sp (Some M.vtbool) (M.Pif (c, et, ef)) in

      aout

    | Eletin (_lv, _t, _e1, _e2, _c) ->
      assert false

    | Ematchwith (_e, _bs) ->
      assert false

    | Equantifier (qt, x, xty, body) -> begin
        if mode <> `Formula then begin
          Env.emit_error env (loc tope, BindingInExpr);
          bailout ()
        end else
          match
            match xty with
            | PT.Qcollection xe ->
              let ast, xe = for_asset_collection_expr mode env xe in
              Option.map (fun (ad, _) -> (Some ast, M.Tasset ad.as_name)) xe
            | PT.Qtype ty ->
              let ty = for_type env ty in
              Option.map (fun ty -> (None, ty)) ty
          with
          | None -> bailout () | Some (ast, xty) ->

            let _, body =
              Env.inscope env (fun env ->
                  let _ : bool = check_and_emit_name_free env x in
                  let env = Env.Local.push env (unloc x, xty) in
                  env, for_formula env body) in

            let qt =
              match qt with
              | PT.Forall -> M.Forall
              | PT.Exists -> M.Exists in

            mk_sp (Some M.vtbool) (M.Pquantifer (qt, x, (ast, xty), body))
      end

    | Eapp      _
    | Eassert   _
    | Eassign   _
    | Ebreak
    | Efailif   _
    | Efor      _
    | Eiter     _
    | Eif       _
    | Erequire  _
    | Ereturn   _
    | Eoption   _
    | Eseq      _
    | Eterm     _
    | Etransfer _
    | Einvalid ->
      Env.emit_error env (loc tope, InvalidExpression);
      bailout ()

  in

  try
    let aout = doit () in

    begin match aout, ety with
      | { type_ = Some from_ }, Some to_ ->
        if not (Type.compatible ~from_ ~to_) then
          Env.emit_error env (loc tope, IncompatibleTypes (from_, to_));

      | _, Some to_ ->
        Env.emit_error env (loc tope, ExpressionExpected)

      | _, _ ->
        ()
    end;

    aout

  with E.Bailout -> dummy ety

(* -------------------------------------------------------------------- *)
and for_asset_expr mode (env : env) (tope : PT.expr) =
  let ast = for_xexpr mode env tope in
  let typ =
    match Option.map Type.as_asset ast.M.type_ with
    | None ->
      None

    | Some None ->
      Env.emit_error env (loc tope, InvalidAssetExpression);
      None

    | Some (Some asset) ->
      Some (Env.Asset.get env (unloc asset))

  in (ast, typ)

(* -------------------------------------------------------------------- *)
and for_asset_collection_expr mode (env : env) (tope : PT.expr) =
  let ast = for_xexpr mode env tope in
  let typ =
    match Option.map Type.as_asset_collection ast.M.type_ with
    | None ->
      None

    | Some None ->
      Env.emit_error env (loc tope, InvalidAssetCollectionExpr);
      None

    | Some (Some (asset, c)) ->
      Some (Env.Asset.get env (unloc asset), c)

  in (ast, typ)

(* -------------------------------------------------------------------- *)
and for_gen_method_call mode env theloc (the, m, args) =
  let module E = struct exception Bailout end in

  try
    let the, asset = for_asset_collection_expr mode env the in
    let asset, _ = Option.get_fdfl (fun () -> raise E.Bailout) asset in
    let method_ =
      match Mid.find_opt (unloc m) methods with
      | None ->
        Env.emit_error env (loc m, NoSuchMethod (unloc m));
        raise E.Bailout
      | Some method_ -> method_
    in

    let args =
      match args with
      | [ {pldesc = Etuple l; _} ] -> l
      | _ -> args
    in

    let ne = List.length (fst method_.mth_sig) in
    let ng = List.length args in

    if ne <> ng then begin
      Env.emit_error env (theloc, InvalidNumberOfArguments (ne, ng));
      raise E.Bailout
    end;

    let doarg arg (aty : mthtyp) =
      match aty with
      | `Pk ->
        let _, pk = List.find
            (fun (x, _) -> unloc x = unloc asset.as_pk)
            asset.as_fields in
        M.AExpr (for_xexpr mode env ~ety:pk arg)

      | `The ->
        M.AExpr (for_xexpr mode env ~ety:(Tasset asset.as_name) arg)

      | `Pred ->
        let theid = mkloc (loc arg) "the" in
        let thety = M.Tasset asset.as_name in
        let _ : bool = check_and_emit_name_free env theid in
        let env = Env.Local.push env (unloc theid, thety) in
        M.AFun (theid, thety, for_xexpr mode env ~ety:M.vtbool arg)

      | `RExpr ->
        let theid = mkloc (loc arg) "the" in
        let thety = M.Tasset asset.as_name in
        let _ : bool = check_and_emit_name_free env theid in
        let env = Env.Local.push env (unloc theid, thety) in
        let e = for_xexpr mode env arg in

        e.M.type_ |> Option.iter (fun ty ->
            if not (Type.is_numeric ty) then
              Env.emit_error env (loc arg, NumericExpressionExpected));
        M.AFun (theid, thety, e)

      | `Effect ->
        M.AEffect (Option.get_dfl [] (for_arg_effect mode env asset arg))

      | `SubColl ->
        let ty = M.Tcontainer (Tasset asset.as_name, M.Collection) in
        M.AExpr (for_xexpr mode env ~ety:ty arg)

      | _ ->
        assert false

    in

    let args = List.map2 doarg args (fst method_.mth_sig) in
    let amap =
      let aout = ref Mint.empty in
      List.iteri (fun i arg ->
          match arg with
          | M.AExpr { M.type_ = Some ty } ->
            aout := Mint.add i ty !aout
          | M.AFun (_, _, { M.type_ = Some ty }) ->
            aout := Mint.add i ty !aout
          | _ -> ()) args; !aout in

    Some (the, asset, method_, args, amap)

  with E.Bailout -> None

(* -------------------------------------------------------------------- *)
and for_arg_effect mode (env : env) (asset : assetdecl) (tope : PT.expr) =
  match unloc tope with
  | Erecord fields ->
    let do1 map ((x, e) : PT.record_item) =
      match x with
      | None ->
        Env.emit_error env (loc tope, AnonymousFieldInEffect);
        map

      | Some (op, x) -> begin
          match List.Exn.assoc_map unloc (unloc x) asset.as_fields with
          | Some fty ->
            let op  = for_assignment_operator op in
            let e   = for_assign_expr mode env (loc x) (op, fty) e in

            if Mid.mem (unloc x) map then begin
              Env.emit_error env (loc x, DuplicatedFieldInRecordLiteral (unloc x));
              map
            end else
              Mid.add (unloc x) (x, `Assign op, e) map

          | None ->
            Env.emit_error env (loc x, UnknownField (unloc asset.as_name, unloc x));
            map
        end
    in

    let effects = List.fold_left do1 Mid.empty fields in

    Some (List.map snd (Mid.bindings effects))

  | _ ->
    Env.emit_error env (loc tope, InvalidExpressionForEffect);
    None

(* -------------------------------------------------------------------- *)
and for_assign_expr mode env orloc (op, fty) e =
  let ety =
    match op with
    | ValueAssign ->
      Some fty

    | PlusAssign
    | MinusAssign
    | MultAssign
    | DivAssign ->
      if not (Type.is_numeric fty) then begin
        Env.emit_error env (orloc, NumericExpressionExpected);
        None
      end else
        Some fty

    | AndAssign
    | OrAssign ->
      if not (Type.compatible ~from_:fty ~to_:M.vtbool) then
        Env.emit_error env (orloc, IncompatibleTypes (fty, M.vtbool));
      Some M.vtbool

  in for_xexpr mode env ?ety e

(* -------------------------------------------------------------------- *)
and for_formula (env : env) (topf : PT.expr) : M.pterm =
  let e = for_xexpr `Formula env topf in
  Option.iter (fun ety ->
      if ety <> M.vtbool then
        Env.emit_error env (loc topf, FormulaExpected))
    e.type_; e

(* -------------------------------------------------------------------- *)
and for_action_description (env : env) (sa : PT.security_arg) : M.action_description =
  match unloc sa with
  | Sident { pldesc = "anyaction" } ->
    M.ADAny

  | Sapp (act, [{ pldesc = PT.Sident asset }]) -> begin
      let asset = mkloc (loc asset) (PT.Eterm (None, None, asset)) in
      let asset = for_asset_collection_expr `Formula env asset in

      match snd asset with
      | None ->
        M.ADAny

      | Some (decl, _) ->
        M.ADOp (unloc act, decl.as_name)
    end

  | _ ->
    Env.emit_error env (loc sa, InvalidActionDescription);
    M.ADAny

(* -------------------------------------------------------------------- *)
and for_security_action (env : env) (sa : PT.security_arg) : M.security_action =
  match unloc sa with
  | Sident id ->
    begin
      match unloc id with
      | "anyaction" -> Sany
      | _           ->
        let ad = Env.Action.lookup env (unloc id) in

        if Option.is_none ad then
          Env.emit_error env (loc id, UnknownAction (unloc id));

        Sentry [id]
    end

  | Slist sas ->
    M.Sentry (List.flatten (List.map (
        fun x ->
          let a = for_security_action env x in
          match a with
          | Sentry ids -> ids
          | _ -> assert false) sas))

  | _ ->
    Env.emit_error env (loc sa, InvalidSecurityAction);
    Sentry []

(* -------------------------------------------------------------------- *)
and for_security_role (env : env) (sa : PT.security_arg) : M.security_role list =
  match unloc sa with
  | Sident id ->
    Option.get_as_list (for_role env id)

  | _ ->
    Env.emit_error env (loc sa, InvalidSecurityRole);
    []

(* -------------------------------------------------------------------- *)
and for_role (env : env) (name : PT.lident) =
  match Env.Var.lookup env (unloc name) with
  | None ->
    Env.emit_error env (loc name, UnknownLocalOrVariable (unloc name));
    None

  | Some nty ->
    if not (Type.compatible ~from_:nty.vr_type ~to_:M.vtrole) then
      (Env.emit_error env (loc name, NotARole (unloc name)); None)
    else Some name

(* -------------------------------------------------------------------- *)
let for_expr (env : env) ?(ety : M.type_ option) (tope : PT.expr) : M.pterm =
  for_xexpr `Expr env ?ety tope

(* -------------------------------------------------------------------- *)
let for_lbl_expr (env : env) (topf : PT.label_expr) : env * (M.lident option * M.pterm) =
  (* FIXME: check for duplicates *)
  env, (Some (fst (unloc topf)), for_expr env (snd (unloc topf)))

(* -------------------------------------------------------------------- *)
let for_lbls_expr (env : env) (topf : PT.label_exprs) : env * (M.lident option * M.pterm) list =
  List.fold_left_map for_lbl_expr env topf

(* -------------------------------------------------------------------- *)
let for_lbl_formula (env : env) (topf : PT.label_expr) : env * (M.lident option * M.pterm) =
  (* FIXME: check for duplicates *)
  env, (Some (fst (unloc topf)), for_formula env (snd (unloc topf)))

(* -------------------------------------------------------------------- *)
let for_xlbls_formula (env : env) (topf : PT.label_exprs) : env * (M.lident option * M.pterm) list =
  List.fold_left_map for_lbl_formula env topf

(* -------------------------------------------------------------------- *)
let for_lbls_formula (env : env) (topf : PT.label_exprs) : env * M.pterm list =
  snd_map (List.map snd) (List.fold_left_map for_lbl_formula env topf)

(* -------------------------------------------------------------------- *)
let for_arg_decl (env : env) ((x, ty, _) : PT.lident_typ) =
  let ty = for_type env ty in
  let b  = check_and_emit_name_free env x in

  match b, ty with
  | true, Some ty ->
    (Env.Local.push env (unloc x, ty), Some (x, ty))

  | _, _ ->
    (env, None)

(* -------------------------------------------------------------------- *)
let for_args_decl (env : env) (xs : PT.args) =
  List.fold_left_map for_arg_decl env xs

(* -------------------------------------------------------------------- *)
let for_lvalue (env : env) (e : PT.expr) : (M.lident * M.ptyp) option =
  match unloc e with
  | Eterm (None, None, x) -> begin
      match Env.lookup env (unloc x) with
      | Some (`Local xty) ->
        Some (x, xty)

      | Some (`Global vd) ->
        if vd.vr_kind <> `Variable then
          Env.emit_error env (loc e, ReadOnlyGlobal (unloc x));
        Some (x, vd.vr_type)

      | _ ->
        Env.emit_error env (loc e, UnknownLocalOrVariable (unloc x));
        None
    end

  | _ ->
    Env.emit_error env (loc e, InvalidLValue); None

(* -------------------------------------------------------------------- *)
let rec for_instruction (env : env) (i : PT.expr) : env * M.instruction =
  let module E = struct exception Failure end in

  let bailout () = raise E.Failure in

  let mki ?label ?(subvars=[]) node : M.instruction =
    M.{ node; label; subvars; loc = loc i; } in

  let mkseq i1 i2 =
    let asblock = function M.{ node = Iseq is } -> is | _ as i -> [i] in
    match asblock i1 @ asblock i2 with
    | [i] -> i
    | is  -> mki (Iseq is) in

  try
    match unloc i with
    | Emethod (the, m, args) ->
      let infos = for_gen_method_call `Expr env (loc i) (the, m, args) in
      let the, asset, method_, args, _ = Option.get_fdfl bailout infos in
      env, mki (M.Icall (Some the, M.Cconst method_.mth_name, args))

    | Eseq (i1, i2) ->
      let env, i1 = for_instruction env i1 in
      let env, i2 = for_instruction env i2 in
      env, mkseq i1 i2

    | Eassign (op, plv, pe) -> begin
        let lv = for_lvalue env plv in
        let x  = Option.get_dfl (mkloc (loc plv) "<error>") (Option.map fst lv) in
        let op = for_assignment_operator op in

        let e  =
          match lv with
          | None ->
            for_expr env pe

          | Some (_, fty) ->
            for_assign_expr `Expr env (loc plv) (op, fty) pe
        in

        env, mki (M.Iassign (op, x, e))
      end

    | Etransfer (e, back, to_) ->
      let to_ = Option.bind (for_role env) to_ in
      let to_ = Option.map (M.mk_id M.vtrole) to_ in
      let e   = for_expr env ~ety:M.vtcurrency e in
      env, mki (Itransfer (e, back, to_))

    | Eif (c, bit, bif) ->
      let c        = for_expr env ~ety:M.vtbool c in
      let env, cit = for_instruction env bit in
      let cif      = Option.map (for_instruction env) bif in
      let env, cif = Option.get_dfl (env, mki (Iseq [])) cif in
      env, mki (M.Iif (c, cit, cif))

    | Eletin (x, ty, e1, e2, eo) ->
      if Option.is_some eo then
        Env.emit_error env (loc i, LetInElseInInstruction);
      let ty = Option.bind (for_type env) ty in
      let e  = for_expr env ?ety:ty e1 in
      let env, body =
        Env.inscope env (fun env ->
            let _ : bool = check_and_emit_name_free env x in
            let env =
              if Option.is_some e.M.type_ then
                Env.Local.push env (unloc x, Option.get e.M.type_)
              else env in

            for_instruction env e2) in

      env, mki (M.Iletin (x, e, body))

    | Efor (lbl, x, e, i) ->
      let e, asset = for_asset_collection_expr `Expr env e in
      let asset = Option.map fst asset in
      let env, i = Env.inscope env (fun env ->
          let _ : bool = check_and_emit_name_free env x in
          let env, aname =
            if Option.is_some asset then
              let nm = (Option.get asset).as_name in
              let ty = M.Tasset nm in
              Env.Local.push env (unloc x, ty), Some (unloc nm)
            else env, None in

          let env =
            match aname with
            | None ->
              env
            | Some aname ->
              Option.fold (fun env lbl ->
                  if (check_and_emit_name_free env lbl) then
                    Env.Label.push env (unloc lbl, `Loop aname)
                  else env) env lbl
          in for_instruction env i) in

      env, mki (M.Ifor (x, e, i)) ?label:(Option.map unloc lbl)

    | Eiter (lbl, x, a, b, i) ->
      let zero_b = M.mk_sp (M.BVint Big_int.zero_big_int) ~type_:M.vtint in
      let zero : M.pterm = M.mk_sp (M.Plit zero_b) ~type_:M.vtint in
      let a = Option.map_dfl (fun x -> for_expr env ~ety:M.vtint x) zero a in
      let b = for_expr env ~ety:M.vtint b in
      let env, i = Env.inscope env (fun env ->
          let _ : bool = check_and_emit_name_free env x in
          let env = Env.Local.push env (unloc x, M.vtint) in
          for_instruction env i) in
      env, mki (M.Iiter (x, a, b, i)) ?label:(Option.map unloc lbl)

    | Erequire e ->
      let e = for_formula env e in
      env, mki (M.Irequire (true, e))

    | Efailif e ->
      let e = for_formula env e in
      env, mki (M.Irequire (false, e))

    | Eassert lbl ->
      let env =
        if (check_and_emit_name_free env lbl) then
          Env.Label.push env (unloc lbl, `Plain)
        else env in
      env, mki (Ilabel lbl)

    | _ ->
      Env.emit_error env (loc i, InvalidInstruction);
      bailout ()

  with E.Failure ->
    env, mki (Iseq [])

(* -------------------------------------------------------------------- *)
let for_specification_item (env : env) (v : PT.specification_item) : env * env ispecification =
  match unloc v with
  | PT.Vpredicate (x, args, f) ->
    let env, (args, f) =
      Env.inscope env (fun env ->
          let env, args = for_args_decl env args in
          let args = List.pmap id args in
          let f = for_formula env f in
          (env, (args, f)))
    in env, `Predicate (x, args, f)

  | PT.Vdefinition (x, ty, y, f) ->
    let env, (arg, f) =
      Env.inscope env (fun env ->
          let env, arg = for_arg_decl env (y, ty, None) in
          let f = for_formula env f in
          (env, (arg, f)))
    in env, `Definition (x, arg, f)

  | PT.Vlemma (x, f) ->
    let f = for_formula env f in
    (env, `Lemma (x, f))

  | PT.Vtheorem (x, f) ->
    let f = for_formula env f in
    (env, `Theorem (x, f))

  | PT.Vvariable (x, ty, e) ->
    let ty = for_type env ty in
    let e  = Option.map (for_expr env ?ety:ty) e in
    (env, `Variable (x, e))

  | PT.Vassert (x, f, invs, uses) -> begin
      let env0 =
        match Env.Label.lookup env (unloc x) with
        | None ->
          Env.emit_error env (loc x, UnknownLabel (unloc x));
          env
        | Some (env, _) ->
          env
      in

      let for_inv (lbl, linvs) =
        (lbl, List.map (for_formula env0) linvs) in

      let f    = for_formula env0 f in
      let invs = List.map for_inv invs in

      (env, `Assert (x, f, invs, uses))
    end

  | PT.Veffect i ->
    let i = for_instruction env i in
    (env, `Effect i)

  | PT.Vpostcondition (x, f, invs, uses) ->
    let for_inv (lbl, linvs) =
      let env0 =
        match Env.Label.lookup env (unloc lbl) with
        | None ->
          Env.emit_error env (loc lbl, UnknownLabel (unloc lbl));
          env
        | Some (_, `Plain) ->
          Env.emit_error env (loc lbl, NonLoopLabel (unloc lbl));
          env
        | Some (env, `Loop aname) ->
          let ty = M.Tasset (mkloc (loc lbl) aname) in
          let ty = M.Tcontainer (ty, M.Subset) in
          Env.Local.push env ("toiterate", ty)
      in (lbl, List.map (for_formula env0) linvs) in
    let f    =
      let env0 = Option.fst (Env.Label.lookup env (unloc x)) in
      let env0 = Option.get_dfl env env0 in
      for_formula env0 f in
    let invs = List.map for_inv invs in
    (env, `Postcondition (x, f, invs, uses))

(* -------------------------------------------------------------------- *)
let for_security_item (env : env) (v : PT.security_item) : (env * M.security_item) option =
  let module E = struct exception Bailout end in

  try
    let l, (lbl, name, args) = Location.deloc v in

    (* FIXME: check and add label in env *)

    let sp_ =
      match Mid.find_opt (unloc name) security_preds with
      | None ->
        Env.emit_error env (loc name, NoSuchSecurityPredicate (unloc name));
        raise E.Bailout
      | Some method_ -> method_
    in

    let ne = List.length sp_.sp_sig in
    let ng = List.length args in

    if ne <> ng then begin
      Env.emit_error env (l, InvalidNumberOfArguments (ne, ng));
      raise E.Bailout
    end;

    (* let doarg arg (aty : sptyp) =
       match aty with
       | `ActionDesc ->
        for_action_description env arg
       | `Role ->
        for_security_role env arg
       | `Action ->
        for_security_action env arg

       | _ -> assert false
       in *)

    let security_node : M.security_node =
      let id = unloc name in
      match id, args with
      | "only_by_role",           [a; b]    -> M.SonlyByRole         (for_action_description env a, for_security_role env b)
      | "only_in_action",         [a; b]    -> M.SonlyInAction       (for_action_description env a, for_security_action env b)
      | "only_by_role_in_action", [a; b; c] -> M.SonlyByRoleInAction (for_action_description env a, for_security_role env b, for_security_action env c)
      | "not_by_role",            [a; b]    -> M.SnotByRole          (for_action_description env a, for_security_role env b)
      | "not_in_action",          [a; b]    -> M.SnotInAction        (for_action_description env a, for_security_action env b)
      | "not_by_role_in_action",  [a; b; c] -> M.SnotByRoleInAction  (for_action_description env a, for_security_role env b, for_security_action env c)
      | "transferred_by",         [a]       -> M.StransferredBy      (for_action_description env a)
      | "transferred_to",         [a]       -> M.StransferredTo      (for_action_description env a)
      | "no_storage_fail",        [a]       -> M.SnoStorageFail      (for_security_action env a)
      | _ -> assert false
    in

    let security_predicate : M.security_predicate = M.{
        s_node = security_node;
        loc = l;
      }
    in

    let security_item : M.security_item = M.{
        label = lbl;
        predicate = security_predicate;
        loc = l;
      }
    in

    Some (env, security_item)
  with E.Bailout -> None

(* -------------------------------------------------------------------- *)
let for_specification (env : env) (v : PT.specification) =
  List.fold_left_map for_specification_item env (fst (unloc v))

(* -------------------------------------------------------------------- *)
let for_security (env : env) (v : PT.security) : env * M.security =
  let env, items = List.fold_left (fun (env, items) x ->
      match for_security_item env x with
      | Some (e, v) -> (e, v::items)
      | None -> (env, items)
    ) (env, []) (fst (unloc v)) in
  env, M.{ items = List.rev items;
           loc = loc v }

(* -------------------------------------------------------------------- *)
let for_named_state (env : env) (x : PT.lident) =
  let state = Env.State.byname env (unloc x) in
  if Option.is_none state then
    Env.emit_error env (loc x, UnknownState (unloc x));
  state

(* -------------------------------------------------------------------- *)
let for_state (env : env) (st : PT.expr) : ident option =
  match unloc st with
  | Eterm (None, None, x) ->
    for_named_state env x

  | _ ->
    Env.emit_error env (loc st, InvalidStateExpression);
    None

(* -------------------------------------------------------------------- *)
let for_function (env : env) (f : PT.s_function loced) : unit =
  assert false

(* -------------------------------------------------------------------- *)
let rec for_callby (env : env) (cb : PT.expr) =
  match unloc cb with
  | Eterm (None, None, name) when String.equal (unloc name) "any" ->
    [name]

  | Eterm (None, None, name) ->
    Option.get_as_list (for_role env name)

  | Eapp (Foperator { pldesc = `Logical Or }, [e1; e2]) ->
    (for_callby env e1) @ (for_callby env e2)

  | _ ->
    Env.emit_error env (loc cb, InvalidCallByExpression);
    []

(* -------------------------------------------------------------------- *)
let for_action_properties (env : env) (act : PT.action_properties) =
  let calledby = Option.map (fun (x, _) -> for_callby env x) act.calledby in
  let env, req = Option.foldmap
      (fun env (x, _) -> for_lbls_formula env x) env act.require in
  let env, fai = Option.foldmap
      (fun env (x, _) -> for_lbls_formula env x) env act.failif in
  let spec    = Option.map (for_specification env) act.spec in
  let funs     = List.map (for_function env) act.functions in

  (env, (calledby, req, fai, spec, funs))

(* -------------------------------------------------------------------- *)
let for_effect (env : env) (effect : PT.expr) =
  for_instruction env effect

(* -------------------------------------------------------------------- *)
let for_transition (env : env) (state, when_, effect) =
  let state = for_named_state env state in
  let when_ = Option.map (fun (x, _) -> for_formula env x) when_ in
  let effect = Option.map (fun (x, _) -> for_effect env x) effect in

  (state, when_, effect)

(* -------------------------------------------------------------------- *)
type state = ((PT.lident * PT.enum_option list) list)

let for_state_decl (env : env) (state : state loced) =
  (* FIXME: check that ctor names are available *)

  let ctors = unloc state in

  match ctors with
  | [] ->
    Env.emit_error env (loc state, EmptyStateDecl);
    env, None

  | _ ->
    Option.iter
      (fun (_, x) ->
         Env.emit_error env (loc x, DuplicatedCtorName (unloc x)))
      (List.find_dup unloc (List.map fst ctors));

    let ctors = Mid.collect (unloc : M.lident -> ident) ctors in

    let for1 (cname, options) =
      let init, inv =
        List.fold_left (fun (init, inv) option ->
            match option with
            | PT.EOinitial ->
              (init+1, inv)
            | PT.EOspecification spec ->
              (init, List.rev_append spec inv)
          ) (0, []) options in

      if init > 1 then
        Env.emit_error env (loc cname, DuplicatedInitMarkForCtor);
      (init <> 0, List.rev inv) in

    let for1 env ((cname : PT.lident), options) =
      let init, inv = for1 (cname, options) in
      let env , inv = for_lbls_formula env inv in

      (env, (cname, init, inv)) in

    let env, ctors = List.fold_left_map for1 env ctors in

    let ictor =
      let ictors =
        List.pmap
          (fun (x, b, _) -> if b then Some x else None)
          ctors in

      match ictors with
      | [] ->
        proj3_1 (List.hd ctors)
      | init :: ictors ->
        if not (List.is_empty ictors) then
          Env.emit_error env (loc state, MultipleInitialMarker);
        init in

    env, Some (unloc ictor, List.map (fun (x, _, inv) -> (x, inv)) ctors)

(* -------------------------------------------------------------------- *)
let for_varfun_decl (env : env) (decl : varfun loced) =
  match unloc decl with
  | `Variable (x, ty, e, _tgts, ctt, _) ->
    (* FIXME: handle tgts *)

    let ty   = for_type env ty in
    let e    = Option.map (for_expr env ?ety:ty) e in
    let dty  =
      if   Option.is_some ty
      then ty
      else Option.bind (fun e -> e.M.type_) e in
    let ctt  = match ctt with
      | VKconstant -> `Constant
      | VKvariable -> `Variable in

    if Option.is_some dty then begin
      let decl = {
        vr_name = x  ; vr_type = Option.get dty;
        vr_kind = ctt; vr_core = None          ;
        vr_def  = Option.map (fun e -> (e, `Std)) e; } in

      if   (check_and_emit_name_free env x)
      then (Env.Var.push env decl, Some (`Variable decl))
      else (env, None)
    end else (env, None)

  | `Function fdecl ->
    let env, _   = Env.inscope env (fun env ->
        let env    = fst (for_args_decl env fdecl.args) in
        let rty    = Option.bind (for_type env) fdecl.ret_t in
        let _body  = for_expr env ?ety:rty fdecl.body in
        let _spec = Option.map (for_specification env) fdecl.spec in
        env, ()) in (env, None)

(* -------------------------------------------------------------------- *)
let for_varfuns_decl (env : env) (decls : varfun loced list) =
  List.fold_left_map for_varfun_decl env decls

(* -------------------------------------------------------------------- *)
let for_asset_decl (env : env) (decl : PT.asset_decl loced) =
  let (x, fields, opts, invs, _, _) = unloc decl in

  let for_field field =
    let PT.Ffield (f, fty, init, _) = unloc field in
    let fty  = for_type env fty in
    let init = Option.map (for_expr env ?ety:fty) init in
    mkloc (loc f) (unloc f, fty, init) in

  let fields = List.map for_field fields in

  Option.iter
    (fun (_, { plloc = lc; pldesc = (name, _, _) }) ->
       Env.emit_error env (lc, DuplicatedFieldInAssetDecl name))
    (List.find_dup (fun x -> proj3_1 (unloc x)) fields);

  let get_field name =
    List.Exn.find
      (fun { pldesc = (x, _, _) } -> x = name)
      fields
  in

  (* FIXME: check for duplicated type name? *)

  let pk, sortk =
    let dokey key =
      if Option.is_none (get_field (unloc key)) then begin
        Env.emit_error env (loc key, UnknownFieldName (unloc key));
        None
      end else Some key in

    let do1 (pk, sortk) = function
      | PT.AOidentifiedby newpk ->
        if Option.is_some pk then
          Env.emit_error env (loc newpk, DuplicatedPKey);
        let newpk = dokey newpk in
        ((if Option.is_some pk then pk else newpk), sortk)

      | PT.AOsortedby newsortk ->
        let newsortk = dokey newsortk in
        (pk, Option.fold (fun sortk newsortk -> newsortk :: sortk) sortk newsortk)

    in List.fold_left do1 (None, []) opts in

  let sortk = List.rev sortk in

  let env, invs =
    let for1 env = function
      | PT.APOconstraints invs ->
        Env.inscope env (fun env ->
            let env =
              List.fold_left (fun env { pldesc = (f, fty, _) } ->
                  Option.fold (fun env fty -> Env.Local.push env (f, fty)) env fty)
                env fields
            in for_xlbls_formula env invs)

      | _ ->
        env, []
    in List.fold_left_map for1 env invs in

  if Env.Asset.exists env (unloc x) then begin
    Env.emit_error env (loc x, DuplicatedAssetName (unloc x));
    (env, None)
  end else
    let module E = struct exception Bailout end in

    if List.is_empty fields then begin
      Env.emit_error env (loc decl, AssetWithoutFields);
      raise E.Bailout
    end;

    let get_field_type { plloc = loc; pldesc = (x, ty, e) } =
      let ty =
        if   Option.is_some ty
        then ty
        else Option.bind (fun e -> e.M.type_) e
      in (mkloc loc x, Option.get_fdfl (fun () -> raise E.Bailout) ty)
    in

    try
      let decl = {
        as_name   = x;
        as_fields = List.map get_field_type fields;
        as_pk     = Option.get_fdfl
            (fun () -> L.lmap proj3_1 (List.hd fields))
            pk;
        as_sortk  = sortk;
        as_invs   = List.flatten invs;
      } in (Env.Asset.push env decl, Some decl)
    with E.Bailout -> (env, None)

(* -------------------------------------------------------------------- *)
let for_assets_decl (env : env) (decls : PT.asset_decl loced list) =
  List.fold_left_map for_asset_decl env decls

(* -------------------------------------------------------------------- *)
let for_acttx_decl (env : env) (decl : acttx loced) =
  match unloc decl with
  | `Action (x, args, pt, i_exts, _exts) -> begin
      let env, decl =
        Env.inscope env (fun env ->
            let env, args   = for_args_decl env args in
            let env, effect = Option.foldmap for_instruction env (Option.fst i_exts) in
            let callby      = Option.map (for_callby env) (Option.fst pt.calledby) in
            let callby      = Option.get_dfl [] callby in
            let env, reqs   = Option.foldmap for_lbls_expr env (Option.fst pt.require) in
            let env, fais   = Option.foldmap for_lbls_expr env (Option.fst pt.failif) in
            let env, spec  = Option.foldmap for_specification env pt.spec in

            let decl =
              { ad_name   = x;
                ad_args   = List.pmap (fun x -> x) args;
                ad_callby = callby;
                ad_effect = effect;
                ad_reqs   = Option.get_dfl [] reqs;
                ad_fais   = Option.get_dfl [] fais;
                ad_spec   = Option.get_dfl [] spec; } in

            (env, decl))

      in (Env.Action.push env decl, decl)
    end

  | `Transition (x, args, tgt, from_, actions, tx, _exts) ->
    assert false
    (*

    let _env0  = for_args_decl env args in
    let _from_ = for_state env from_ in
    let env, act = for_action_properties env actions in
    let _tx = List.map (for_transition env) tx in

    if Option.is_some tgt then
      assert false;

    env
    *)
(* -------------------------------------------------------------------- *)
let for_acttxs_decl (env : env) (decls : acttx loced list) =
  List.fold_left_map for_acttx_decl env decls

(* -------------------------------------------------------------------- *)
let for_specs_decl (env : env) (decls : PT.specification loced list) =
  List.fold_left_map
    (fun env { pldesc = x } -> for_specification env x)
    env decls

(* -------------------------------------------------------------------- *)
let for_secs_decl (env : env) (decls : PT.security loced list) =
  List.fold_left_map
    (fun env { pldesc = x } -> for_security env x)
    env decls

(* -------------------------------------------------------------------- *)
let group_declarations (decls : (PT.declaration list)) =
  let empty = {
    gr_archetypes = [];
    gr_states     = [];
    gr_enums      = [];
    gr_assets     = [];
    gr_varfuns    = [];
    gr_acttxs     = [];
    gr_specs      = [];
    gr_secs       = [];
  } in

  let for1 { plloc = loc; pldesc = decl } (g : groups) =
    let mk x = Location.mkloc loc x in

    match decl with
    | PT.Darchetype (x, exts) ->
      { g with gr_archetypes = mk (x, exts) :: g.gr_archetypes }

    | PT.Dvariable infos ->
      { g with gr_varfuns = mk (`Variable infos) :: g.gr_varfuns }

    | PT.Denum (PT.EKstate, infos) ->
      { g with gr_states = mk infos :: g.gr_states }

    | PT.Denum (PT.EKenum x, infos) ->
      { g with gr_enums = mk (x, infos) :: g.gr_enums }

    | PT.Dasset infos ->
      { g with gr_assets = mk infos :: g.gr_assets }

    | PT.Daction infos ->
      { g with gr_acttxs = mk (`Action infos) :: g.gr_acttxs }

    | PT.Dtransition infos ->
      { g with gr_acttxs = mk (`Transition infos) :: g.gr_acttxs }

    | PT.Dfunction infos ->
      { g with gr_varfuns = mk (`Function infos) :: g.gr_varfuns }

    | PT.Dspecification infos ->
      { g with gr_specs = mk infos :: g.gr_specs }

    | PT.Dsecurity infos ->
      { g with gr_secs = mk infos :: g.gr_secs }

    | Dinstance _
    | Dcontract  _
    | Dnamespace _
    | Dextension _
    | Dinvalid      -> assert false

  in List.fold_right for1 decls empty

(* -------------------------------------------------------------------- *)
let for_grouped_declarations (env : env) (toploc, g) =
  if not (List.is_empty g.gr_archetypes) then
    Env.emit_error env (toploc, InvalidArcheTypeDecl);

  if List.length g.gr_states > 1 then
    Env.emit_error env (toploc, MultipleStateDeclaration);

  let _state, env =
    let for1 { plloc = loc; pldesc = state } =
      match for_state_decl env (mkloc loc (fst state)) with
      | env, Some state -> Some (env, state)
      | _  , None       -> None in

    match List.pmap for1 g.gr_states with
    | (env, (init, ctors)) :: _ ->
      let decl = { sd_ctors = ctors; sd_init = init; } in
      (Some decl, Env.State.push env decl)
    | _ ->
      (None, env) in

  let env, adecls = for_assets_decl  env g.gr_assets  in
  let env, fdecls = for_varfuns_decl env g.gr_varfuns in
  let env, tdecls = for_acttxs_decl  env g.gr_acttxs  in
  let env, vdecls = for_specs_decl   env g.gr_specs   in
  let env, sdecls = for_secs_decl    env g.gr_secs   in

  (env, (adecls, fdecls, tdecls, vdecls, sdecls))

(* -------------------------------------------------------------------- *)
let assets_of_adecls adecls =
  let for1 (decl : assetdecl) =
    let for_field (f, fty) =
      M.{ name = f; typ = Some fty; default = None; loc = loc f; } in

    let spec (l, f) =
      M.{ label = l; term = f; loc = f.loc } in

    M.{ name   = decl.as_name;
        fields = List.map for_field decl.as_fields;
        key    = Some decl.as_pk;
        sort   = decl.as_sortk;
        state  = None;           (* FIXME *)
        role   = false;          (* FIXME *)
        init   = None;           (* FIXME *)
        specs  = List.map spec decl.as_invs;
        loc    = loc decl.as_name; }

  in List.map for1 (List.pmap (fun x -> x) adecls)

(* -------------------------------------------------------------------- *)
let variables_of_fdecls fdecls =
  let for1 = function
    | `Variable (decl : vardecl) ->
      M.{ decl =
            M.{ name    = decl.vr_name;
                typ     = Some decl.vr_type;
                default = Option.fst decl.vr_def;
                loc     = loc decl.vr_name; };
          constant = decl.vr_kind = `Constant;
          from     = None;
          to_      = None;
          loc      = loc decl.vr_name; }

  in List.map for1 (List.pmap (fun x -> x) fdecls)

(* -------------------------------------------------------------------- *)
let specifications_of_ispecifications =
  let env0 : M.lident M.specification = M.{
      predicates  = [];
      definitions = [];
      lemmas      = [];
      theorems    = [];
      variables   = [];
      invariants  = [];
      effect      = None;
      specs       = [];
      asserts     = [];
      loc         = L.dummy;      (* FIXME *) } in

  let do1 (env : M.lident M.specification) (ispec : env ispecification) =
    match ispec with
    | `Postcondition (x, e, invs, uses) ->
      let spec =
        let for_inv (lbl, inv) =
          M.{ label = lbl; formulas = inv }
        in
        M.{ name       = x;
            formula    = e;
            invariants = List.map for_inv invs;
            uses       = uses; }
      in { env with M.specs = env.specs @ [spec] }

    | `Assert (x, form, invs, uses) ->
      let asst =
        let for_inv (lbl, inv) =
          M.{ label = lbl; formulas = inv }
        in
        M.{ name       = x;
            label      = x;
            formula    = form;
            invariants = List.map for_inv invs;
            uses       = uses; }
      in { env with M.asserts = env.asserts @ [asst] }

    | _ ->
      assert false

  in fun ispecs -> List.fold_left do1 env0 ispecs

(* -------------------------------------------------------------------- *)
let transactions_of_tdecls tdecls =
  let for_calledby cb : M.rexpr option =
    match cb with [] -> None | c :: cb ->

      let for1 = fun x ->
        let node =
          match unloc x with
          | "any" -> M.Rany
          | _ ->
            let name = M.{ node = M.Qident x; type_ = None; label = None; loc = loc x; } in
            M.Rqualid name
        in
        M.{ node  = node;
            type_ = None;
            label = None;
            loc   = loc x } in
      Some (List.fold_left (fun acc c' ->
          M.{ node  = M.Ror (acc, for1 c');
              type_ = None;
              label = None;
              loc   = L.dummy; }) (for1 c) cb)
  in


  let for1 tdecl =
    M.{ name = tdecl.ad_name;
        args =
          List.map (fun (x, xty) ->
              M.{ name = x; typ = Some xty; default = None; loc = loc x; })
            tdecl.ad_args;
        calledby        = for_calledby tdecl.ad_callby;
        accept_transfer = false;        (* FIXME; false is default *)
        require         = Some (
            List.map
              (fun (x, c) -> M.{ label = x; term = c; loc = L.dummy; }) (* FIXME *)
              tdecl.ad_reqs);
        failif         = Some (
            List.map
              (fun (x, c) -> M.{ label = x; term = c; loc = L.dummy; }) (* FIXME *)
              tdecl.ad_fais);
        transition      = None;        (* FIXME *)
        specification    = Some (specifications_of_ispecifications tdecl.ad_spec);
        functions       = [];          (* FIXME *)
        effect          = tdecl.ad_effect;
        loc             = loc tdecl.ad_name; }

  in List.map for1 tdecls

(* -------------------------------------------------------------------- *)
let for_declarations (env : env) (decls : (PT.declaration list) loced) : M.model =
  let toploc = loc decls in

  match unloc decls with
  | { pldesc = Darchetype (x, _exts) } :: decls ->
    let groups = group_declarations decls in
    let _env, decls = for_grouped_declarations env (toploc, groups) in
    let adecls, fdecls, tdecls, vdecls, sdecls = decls in

    M.mk_model
      ~assets:(assets_of_adecls adecls)
      ~variables:(variables_of_fdecls fdecls)
      ~transactions:(transactions_of_tdecls tdecls)
      ~specifications:(List.map specifications_of_ispecifications vdecls)
      ~securities:sdecls
      x

  | _ ->
    Env.emit_error env (loc decls, InvalidArcheTypeDecl);
    { (M.mk_model (mkloc (loc decls) "<unknown>")) with loc = loc decls }

(* -------------------------------------------------------------------- *)
let typing (env : env) (cmd : PT.archetype) =
  match unloc cmd with
  | Marchetype decls ->
    for_declarations env (mkloc (loc cmd) decls)

  | Mextension _ ->
    assert false