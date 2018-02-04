(* Copyright (C) 2017  Petter A. Urkedal <paurkedal@gmail.com>
 *
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or (at your
 * option) any later version, with the OCaml static compilation exception.
 *
 * This library is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
 * License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this library.  If not, see <http://www.gnu.org/licenses/>.
 *)

(** Request specification.

    A Caqti request is a function to generate a query string from information
    about the driver, along with type descriptors to encode parameters and
    decode rows returned from the same query.  Requests are passed to
    {!Caqti_connection_sig.S.call} or one of its shortcut methods provided by a
    database connection handle.

    The request often represent a prepared query, in which case it is static and
    can be be defined directly in a module scope.  However, an optional
    [oneshot] parameter may be passed to indicate a dynamically generated
    query. *)

(** {2 Primitives} *)

type template =
  | L of string  (** Literal code. May contain incomplete fragments. *)
  | P of int     (** [P i] refers to parameter number [i], counting from 0. *)
  | S of template list (** [S frags] is the concatenation of [frags]. *)
(** A representation of a query string to send to a database, abstracting over
    parameter references and providing nested concatenation to simplify
    generation.  For databases which only support linear parameters (typically
    denoted "[?]"), the driver will reshuffle, elide, and duplicate parameters
    as needed.  *)

type ('a, 'b, +'m) t constraint 'm = [< `Zero | `One | `Many]
(** A request specification embedding a query generator, parameter encoder, and
    row decoder.
    - ['a] is the type of the expected parameter bundle.
    - ['b] is the type of a returned row.
    - ['m] is the possible multiplicities of returned rows. *)

val create :
  ?oneshot: bool ->
  'a Caqti_type.t -> 'b Caqti_type.t -> 'm Caqti_mult.t ->
  (Caqti_driver_info.t -> template) -> ('a, 'b, 'm) t
(** [create arg_type row_type row_mult f] is a request which takes parameters of
    type [arg_type], returns rows of type [row_type] with multiplicity
    [row_mult], and which sends query strings generated from the template [f
    di], where [di] is the {!Caqti_driver_info.t} of the target driver.  The
    driver is responsible for turning parameter references into a form accepted
    by the database, while other differences must be handled by [f]. *)

val param_type : ('a, _, _) t -> 'a Caqti_type.t
(** [param_type req] is the type of parameter bundles expected by [req]. *)

val row_type : (_, 'b, _) t -> 'b Caqti_type.t
(** [row_type req] is the type of rows returned by [req]. *)

val row_mult : (_, _, 'm) t -> 'm Caqti_mult.t
(** [row_mult req] indicates how many rows [req] may return.  This is asserted
    when constructing the query. *)

val query_id : ('a, 'b, 'm) t -> int option
(** If [req] is a prepared query, then [query_id req] is [Some id] for some [id]
    which uniquely identifies [req], otherwise it is [None]. *)

val query_template : ('a, 'b, 'm) t -> Caqti_driver_info.t -> template
(** [query_template req] is the function which generates the query template for
    a driver for this request. *)

(** {2 Convenience}

    In the following functions, queries are written out as plain strings with
    the following syntax, which is parsed by Caqti into a {!template} before
    being passed to the drivers.

    {b Parameters} are specified as either

    - ["?"] for linear substitutions (like Sqlite and MariaDB), or
    - ["$1"], ["$2"], ... for non-linear substitutions (like PostgreSQL).

    Mixing the two styles in the same query is not permitted.  Note than
    numbering of non-linear parameters is offset by one compared to the query
    templates defined in the previous section, in order to be consistent with
    PostgreSQL.

    {b Static references} of the form

    - ["$(<var>)"] is substituted by [env driver_info "<var>"].
    - ["$."] is a shortcut for ["$(.)"].

    are replaced by query fragments returned by the [?env] argument of the
    functions below, and aids in substituting configurable fragments, like
    database schemas or table names.  The latter form is suggested for
    qualifying tables, sequences, etc.  with the main database schema.  It
    should expand to a schema name followed by a dot, or empty if the database
    does not support schemas or the schema is unset.

    Apart from the more generic {!create_p}, these function match up with
    retrieval functions of {!Caqti_connection_sig.S} and {!Caqti_response_sig.S}
    according to the multiplicity parameter of their types. *)

val create_p :
  ?env: (Caqti_driver_info.t -> string -> template) ->
  ?oneshot: bool ->
  'a Caqti_type.t -> 'b Caqti_type.t -> 'm Caqti_mult.t ->
  (Caqti_driver_info.t -> string) -> ('a, 'b, 'm) t
(** [create_p arg_type row_type row_mult f] is a request which takes parameters
    of type [arg_type], returns rows of type [row_type] with multiplicity
    [row_mult], and which sends a query string based on a preliminary form given
    by [f di], where [di] is the {!Caqti_driver_info.t} of the target driver.
    The preliminary query string may contain occurrences of "[?]", which are
    replaced by successive parameter references.  This is implemented as [create
    arg_type row_type (parse % f)] where [parse] parses a string into a
    template.

    @param oneshot
      For queries generated on-demand or which are otherwise executed only once,
      pass [true] do make the query non-prepared.  By default queries are
      prepared, which is suitable for requests defined at the module level.

    @param env
      [env driver_info key] shall provide the value to substitute for a
      reference to [key] in the query string, or raise [Not_found] to indicate
      the reference to [key] is invalid.  [Not_found] will be re-raised as
      [Invalid_argument] with additional information to help locate the bug. *)

val exec :
  ?env: (Caqti_driver_info.t -> string -> template) ->
  ?oneshot: bool ->
  'a Caqti_type.t ->
  string -> ('a, unit, [> `Zero]) t
(** [exec_p arg_type s] is a shortcut for [create_p arg_type Caqti_type.unit
    Caqti_mult.zero (fun _ -> s)]. *)

val find :
  ?env: (Caqti_driver_info.t -> string -> template) ->
  ?oneshot: bool ->
  'a Caqti_type.t -> 'b Caqti_type.t ->
  string -> ('a, 'b, [> `One]) t
(** [find_p arg_type row_type s] is a shortcut for [create_p arg_type row_type
    Caqti_mult.one (fun _ -> s)]. *)

val find_opt :
  ?env: (Caqti_driver_info.t -> string -> template) ->
  ?oneshot: bool ->
  'a Caqti_type.t -> 'b Caqti_type.t ->
  string -> ('a, 'b, [> `Zero | `One]) t
(** [find_opt_p arg_type row_type s] is a shortcut for [create_p arg_type
    row_type Caqti_mult.zero_or_one (fun _ -> s)]. *)

val collect :
  ?env: (Caqti_driver_info.t -> string -> template) ->
  ?oneshot: bool ->
  'a Caqti_type.t -> 'b Caqti_type.t ->
  string -> ('a, 'b, [> `Zero | `One | `Many]) t
(** [collect_p arg_type row_type s] is a shortcut for [create_p arg_type
    row_type Caqti_mult.many (fun _ -> s)]. *)