(** Affymetrix's BAR files. Their Tiling Analysis Software (TAS)
    produces BAR files in binary format but this module supports only the
    text format generated by selecting the "Export probe analysis as TXT"
    option. *)

type t
(** Type of a BAR file, which can be thought of as a header plus set
    of sections. *)

exception Bad of string

type section = private {
  sec_num : int; (** order in which section appears in file, first
                     section is numbered 1 *)
  sec_name : string; (** chromosome name relative to which coordinates
                         are given *)
  sec_data : (int * float) list (** pairs of coordinate-score data *)
}

val of_file : string -> t
(** Parse file. Raise [Bad] if there are parse errors. *)

val to_list : t -> (string * int * float) list
(** Return the data as a list of triplets (chr,pos,v) representing the
    chromosome name, probe position, and value. Will be returned in
    ascending order by (chr,pos). *)

val section : t -> string -> section
(** [section t name] returns the section named [name]. Raise [Failure]
    if no such section. *)

val sectioni : t -> int -> section
(** [sectioni t i] returns the [i]'th section. Raise [Failure] if no
    such section. *)

val sections : t -> section list
(** Return all sections in [t]. *)

val num_sections : t -> int
(** Returns the number of sections in [t] *)

(** {6 Header Information} *)

val data_type : t -> string
(** Return the type of data, either "signal" or "p-value". *)

val scale : t -> string
(** Return scale data is reported in, e.g. linear, log2. *)

val genomic_map : t -> string
(** File path of bpmap file used to generate scores. *)

val alg_name : t -> string
(** Name of algorithm used to generate scores. *)

val alg_version : t -> string
(** Version number of algorithm used. *)

val coord_convention : t -> string
(** Probe coordinate convention used. *)