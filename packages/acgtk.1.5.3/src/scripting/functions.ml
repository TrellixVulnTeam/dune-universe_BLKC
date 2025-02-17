(**************************************************************************)
(*                                                                        *)
(*                 ACG development toolkit                                *)
(*                                                                        *)
(*                  Copyright 2008-2021 INRIA                             *)
(*                                                                        *)
(*  More information on "http://acg.gforge.inria.fr/"                     *)
(*  License: CeCILL, see the LICENSE file or "http://www.cecill.info"     *)
(*  Authors: see the AUTHORS file                                         *)
(*                                                                        *)
(*                                                                        *)
(*                                                                        *)
(*                                                                        *)
(*  $Rev::                              $:  Revision of last commit       *)
(*  $Author::                           $:  Author of last commit         *)
(*  $Date::                             $:  Date of last commit           *)
(*                                                                        *)
(**************************************************************************)

open UtilsLib
open AcgData.Environment

let info fd name =
  let w,h =
    try
      let w,h=ANSITerminal.size () in
      Printf.sprintf "%i" w,Printf.sprintf "%i" h
    with
    | Failure f ->
       let regexp = Str.regexp "ANSITerminal.size" in
       if Str.string_match regexp f 0 then
         "Not set","Not set"
       else
         raise (Failure f)
  in
  Logs.app
    (fun m ->
      m 
        "The file descriptor %s refers to a terminal: %B and the size is (%s,%s)"
        name
        (Unix.isatty fd)
        w
        h)



module type Action_sig = 
sig
  
  type env
  type context

  (*  exception Not_yet_implemented of string *)
  exception Stop
  exception Quit

  type action =
    | Load
    | List
    | Select
    | Unselect
    | Trace
    | Dont_trace
    | Print
    | Analyse
    | Check
    | Realize
    | RealizeShow
    | Add
    | Compose
    | Dont_wait
    | Wait
    | Help of action option
    | Create
    | Save
    | Parse
    | Idb
    | Query
    | Exit


  type file_type =
  | Data
  | Object
  | Script of (string -> context * env -> context * env)

  val color_output : context -> bool -> context

  val set_config : context -> string -> string list -> context

  val resize : context -> bool
    
  val load : file_type -> string -> context * env -> context * env

  val list : context -> env -> unit

  val select : context -> string -> (Lexing.position * Lexing.position) -> env -> env

  val unselect : env -> env

  val trace : context -> (Lexing.position * Lexing.position) -> unit
  val dont_trace : context -> (Lexing.position * Lexing.position) -> unit

  val print : context -> ?name:string -> env -> (Lexing.position * Lexing.position) -> unit

  val analyse : context -> ?names:(string * (Lexing.position * Lexing.position)) list -> env -> string -> (Lexing.position * Lexing.position) -> unit

  val check : context -> ?names:(string * (Lexing.position * Lexing.position)) list -> env -> string -> (Lexing.position * Lexing.position) -> unit

  val realize : context -> ?names:(string * (Lexing.position * Lexing.position)) list -> ?svg_output:string -> env -> string -> (Lexing.position * Lexing.position) -> unit

  val realize_show : ?names:(string * (Lexing.position * Lexing.position)) list -> ?svg_output:string -> context -> env -> string -> (Lexing.position * Lexing.position) -> unit

  val parse : context -> ?name:string -> env -> string -> (Lexing.position * Lexing.position) -> unit

  val idb : ?name:string -> context -> env ->  (Lexing.position * Lexing.position) -> unit

  val query : ?name:string -> context -> env -> string -> (Lexing.position * Lexing.position) -> unit

  val add : ?names:(string * (Lexing.position * Lexing.position)) list -> context -> env -> string -> (Lexing.position * Lexing.position) -> env

  val compose : context -> 
    string * (Lexing.position * Lexing.position) ->
    string * (Lexing.position * Lexing.position) ->
    string * (Lexing.position * Lexing.position) -> env -> env

   val make_context : script_filename:string option -> wait:bool -> colored_output:bool -> pretty_printed_output:bool -> echo:bool -> svg:string option -> dirs:string list -> rendering_config:Rendering_config.config -> parse_fun:(string -> context -> Environment.t -> context * Environment.t) -> context

  val wait : context -> context

  val dont_wait : context -> context

  val should_wait : context -> bool

  val echo : context -> bool

  val svg : context -> string option

  val dirs : context -> string list

  val parse_script : context -> (string -> context -> Environment.t -> context * Environment.t)

  val help : context -> action -> unit

  val exit : unit -> unit


  val create_sig :  (string * (Lexing.position * Lexing.position)) -> env -> env


  val create_lex :  abs:(string * (Lexing.position * Lexing.position)) -> obj:(string * (Lexing.position * Lexing.position)) -> context -> (string * (Lexing.position * Lexing.position)) -> env -> env

  val save : ?names:(string * (Lexing.position * Lexing.position)) list -> context -> string -> env -> (Lexing.position * Lexing.position) -> unit


  val get_filename : context -> string option
  val set_filename : string option -> context -> context
    
end


module Functions =
  struct
    
    module Env = AcgData.Environment.Environment
                   
    type env=Env.t
    (*type entry=Env.entry*)
                 
    type context =
      {
        wait:bool; (* whether a user return keypressed is expected before moving to the next command *)
        colored_output:bool; (* whether the output should be colored *)
        pretty_printed_output:bool; (* whether the output should be pretty printed *)
        echo:bool; (* whether the command should be echoed on the output *)
        dirs:string list; (* list of the included dirs *)
        svg:string option; (* whether a svg output "file" (if relevant) should be produced *)
        rendering_config : Rendering_config.config;
        script_filename:string option; (* the filename when the command is executed while parsing a script file *)
        parse_function: string -> context -> Environment.t -> context * Environment.t;
      }
        
        
        
    (*  exception Not_yet_implemented of string *)
    exception Stop
    exception Quit
                
    (*    let interactive = ref false *)
                          
    (*    let color = ref true *)
                    
    let color_output ctx b = {ctx with colored_output = b}
                           
    let config = ref Rendering_config.default
                     
    let set_config ctx file includes = {ctx with rendering_config=(Rendering_config.get_config file includes)}

    let resize ctx = ctx.pretty_printed_output
                                     
    type file_type =
      | Data
      | Object
      | Script of (string -> context * env -> context * env)
                    
    let make_context ~script_filename ~wait ~colored_output ~pretty_printed_output ~echo ~svg ~dirs ~rendering_config ~parse_fun =
      {
        wait;
        colored_output;
        pretty_printed_output;
        echo;
        dirs;
        svg;
        rendering_config;
        script_filename;
        parse_function=parse_fun;
      }
        
    let wait ctx = {ctx with wait=true}
                     
    let dont_wait ctx  = {ctx with wait=false}
                           
    let should_wait ctx = ctx.wait
                            
    let echo ctx = ctx.echo
                     
    let svg ctx = ctx.svg
                    
    let dirs ctx = ctx.dirs
                     
    let parse_script ctx = ctx.parse_function
                             
                             
                             
                             
    module Data_parser =  Grammars.Parsers
    module ShowI = Show.Make(Env)
                            (Show_text_dejavu)
                            (Show_colors_solarized_dark)
                            (Show_embellish_examples.Make(Show_text_dejavu))
                            
                            
    type action =
      | Load
      | List
      | Select
      | Unselect
      | Trace
      | Dont_trace
      | Print
      | Analyse
      | Check
      | Realize
      | RealizeShow
      | Add
      | Compose
      | Dont_wait
      | Wait
      | Help of action option
      | Create
      | Save
      | Parse
      | Idb
      | Query
      | Exit


    let actions = [Help None;Load;List;Print;Check;Realize;RealizeShow;Parse;Idb;Query;Compose;Analyse;Wait;Dont_wait;Select;Unselect;Create;Add;Save;Trace;Dont_trace;]
                    
                    
    let rec action_to_string = function
      | Load -> "load"
      | List -> "list"
      | Select -> "select"
      | Unselect ->  "unselect"
      | Trace -> "trace"
      | Dont_trace -> "don't trace"
      | Print -> "print"
      | Analyse -> "analyse"
      | Check -> "check"
      | Realize -> "realize"
      | RealizeShow -> "realize_show"
      | Add -> "add"
      | Compose -> "compose"
      | Dont_wait -> "don't wait"
      | Wait -> "wait"
      | Help None -> "help"
      | Help (Some (Help a)) -> action_to_string (Help a)
      | Help (Some a) -> Printf.sprintf "%s help" (action_to_string a)
      | Save -> "save"
      | Create -> "create"
      | Parse -> "parse"
      | Idb -> "idb"
      | Query -> "query"
      | Exit -> "exit"


  let colored_string ctx f s =
    if ctx.colored_output then
      f s
    else
      s
    
  let red ctx s = colored_string ctx Utils.red s
  let green ctx s = colored_string ctx Utils.green s
  let bold ctx s = 
    if ctx.colored_output then
      ANSITerminal.sprintf [ANSITerminal.Bold] "%s" s
    else
      s

  let action_to_string ctx s =
    red ctx (action_to_string s)


  let messages ctx = function
    | Load as command ->
      let options = bold ctx "d|data|s|script|o|object" in
      Utils.format "@[<v5>%s %s file;@ @[loads@ the@ file@ \"file\"@ as@ data@ (\"d\"@ or@ \"data\"@ option),@ as@ an@ object@ (compiled@ data,@ \"o\"@ or@ \"object\"@ option),@ or@ as@ a@ script@ (\"s\"@ or@ \"script\"@ option)@ @]@]@." (action_to_string ctx command) options
    | List as command -> Utils.format "@[<v5>%s;@ @[lists@ the@ signatures@ and@ the@ lexicons@ of@ the@ current@ environment@ @]@]@." (action_to_string ctx command)
    | Select as command -> Utils.format "@[<v5>%s name;@ @[selects@ the@ \"name\"@ signature@ or@ lexicon@ in@ the@ current@ environment@ and@ make@ it@ an@ implicit@ context@ for@ the@ following@ commands@ @]@]@." (action_to_string ctx command)
    | Unselect as command -> Utils.format "@[<v5>%s name;@ @[removes@ any@ selected@ signature@ or@ lexicon@ from@ the@ context@ @]@]@." (action_to_string ctx command)
    | Trace as command -> Utils.format "@[<v5>%s;@ @[traces@ the@ interpretation@ (if@ a@ command@ is@ used@ in@ a@ context@ of@ a@ lexicon)@ and@ the@ beta-reduction@ process@ @]@]@." (action_to_string ctx command)
    | Dont_trace as command -> Utils.format "@[<v5>%s;@ @[stops@ tracing@ @]@]@." (action_to_string ctx command)
    | Wait as command -> Utils.format "@[<v5>%s;@ @[waits@ a@ keyboard@ return@ event@ before@ going@ on@ in@ executing@ a@ script@ @]@]@." (action_to_string ctx command)
    | Dont_wait as command -> Utils.format "@[<v5>%s;@ @[stops@ waiting@ a@ keyboard@ return@ event@ before@ going@ on@ in@ executing@ a@ script@ @]@]@." (action_to_string ctx command)
    | Print as command -> Utils.format "@[<v5>[name] %s;@ @[outputs@ the@ content@ of@ the@ \"name\"@ signature@ or@ lexicon@ of@ the@ current@ environment.@ If@ no@ \"name\"@ is@ specified,@ check@ whether@ there@ is@ a@ selected@ data@ in@ the@ environment@ @]@]@." (action_to_string ctx command)
    | Analyse as command -> Utils.format "@[<v5>[name1 name2 ...] %s term:type;@ @[*DEPRECATED*@]@ @[analyses@ the@ given@ \"term:type\"@ with@ respect@ to@ the@ given@ \"name1\"@ ...@ signatures@ or@ lexicons,@ or@ if@ no@ such@ name@ is@ given,@ with@ respect@ to@ the@ selected@ data@ in@ the@ environment.@ In@ the@ context@ of@ a@ signature,@ this@ command@ just@ typechecks@ the@ given@ entry.@ In@ the@ context@ of@ a@ lexicon,@ it@ typechecks@ it@ and@ interprets@ it@ with@ respect@ to@ this@ lexicon@ @]@]@." (action_to_string ctx command)
    | Check as command -> Utils.format "@[<v5>[name1 name2 ...] %s term:type;@ @[check@ whether@ the@ given@ \"term:type\"@ typechecks@ with@ respect@ to@ the@ given@ \"name1\"@ ...@ signatures,@ or@ if@ no@ such@ name@ is@ given,@ with@ respect@ to@ the@ selected@ data@ in@ the@ environment,@ provided@ it@ is@ a@ signature.@]@]@." (action_to_string ctx command)
    | Realize as command -> Utils.format "@[<v5>[name1 name2 ...] %s term:type;@ @[check@ whether@ the@ given@ \"term:type\"@ typechecks@ with@ respect@ to@ the@ abstract@ signatures@ of@ the@ \"name1\"@ ...@ lexicons,@ or@ if@ no@ such@ name@ is@ given,@ with@ respect@ to@ the@ selected@ data@ in@ the@ environment,@ provided@ it@ is@ a@ lexicon.@ Then@ the@ interrpretetion@ of@ the@ input@ term@ by@ each@ lexicon@ is@ computed.@]@]@." (action_to_string ctx command)
    | RealizeShow as command -> Utils.format "@[<v5>[name1 name2 ...] %s term:type;@ @[same@ as@ realize,@ but@ with@ graphical@ output.@ A@ graph@ illustrating@ the@ images@ of@ the@ supplied@ term@ and@ its@ subterms@ with@ the@ given@ lexicons@ will@ be@ produced@ in@ a@ file@ named@ realize.svg.@]@]@." (action_to_string ctx command)
    | Parse as command -> Utils.format "@[<v5>[name] %s term:type;@ @[parse@ the@ object@ term@ \"term\"@ as@ the@ image@ of@ some@ abstract@ term@ of@ type@ \"type\"@ according@ to@ the@ lexicon@ \"name\".@ If@ no@ \"name\"@ is@ specified,@ check@ whether@ there@ is@ a@ selected@ data@ in@ the@ environment@ @]@]@." (action_to_string ctx command)
    | Idb as command -> Utils.format "@[<v5>[name] %s;@ @[outputs@ the@ datalog@ program@ (intensional@ database)@ corresponding@ to@ the@ lexicon@ \"name\".@ If@ no@ \"name\"@ is@ specified,@ check@ whether@ there@ is@ a@ selected@ data@ in@ the@ environment@ @]@]@." (action_to_string ctx command)
    | Query as command -> Utils.format "@[<v5>[name] %s term:type;@ @[outputs@ the@ facts@ (extensional@ database)@ and@ the@ query@ associated@ to@ the@ term@ \"term\"@ of@ distinguished@ type@ \"type\"@ with@ respect@ to@ the@ lexicon@ \"name\".@ If@ no@ \"name\"@ is@ specified,@ check@ whether@ there@ is@ a@ selected@ data@ in@ the@ environment@ @]@]@." (action_to_string ctx command)
    | Add as command -> Utils.format "@[<v5>[name1 name2 ...] %s expression;@ @[adds@ the@ given@ \"expression\"@ with@ respect@ to@ the@ given@ \"name1\"@ ...@ signatures@ or@ lexicons@ to@ those@ signature@ or@ lexicons.@ \"expression\"@ must@ respect@ the@ syntax@ of@ signatures@ or@ lexicons@ @]@]@." (action_to_string ctx command)
    | Compose as command -> let as_str = red ctx "as" in
			    Utils.format "@[<v5>%s name1 name2 %s name3; @ @[ creates@ a@ new@ lexicon@ with@ name@ \"name3\"@ by@ composing@ the@ \"name1\"@ and@ \"name2\"@ lexicons@ @]@]@." (action_to_string ctx command) as_str
    | Help _ as command -> Utils.format "@[<v5>%s ;@ @[prints@ the@ help@ message@ @]@]@." (action_to_string ctx command)
    | Create as command -> Utils.format "@[<v5>%s s|sig|l|lex name [name1 name2];@ @[creates@ a@ new@ empty@ signature@ or@ lexicon@ (according@ to@ the@ s@ or@ sig,@ or@ l@ or@ lex@ option)@ with@ name@ \"name\"@ in@ the@ current@ environment.\"name1\"@ and@ \"name2\"@ are@ mandatory@ in@ case@ of@ creating@ a@ lexicon:@ they@ are@ respectively@ the@ abstract@ and@ the@ object@ signature.@ They@ of@ course@ are@ forbidden@ in@ case@ of@ creating@ a@ signature@ @]@]@." (action_to_string ctx command)
    | Save as command -> Utils.format "@[<v5>[name1 name2 ...] %s filename;@ @[outputs@ the@ content@ of@ \"name1\",@ \"name2\"...@ into@ the@ same@ file@ \"filename\".@ If@ no@ \"name\"@ is@ specified,@ check@ whether@ there@ is@ a@ selected@ data@ in@ the@ environment@ @]@]@." (action_to_string ctx command)
    | Exit as command -> Utils.format "@[<v5>%s;@ @[quits@ the@ program@ @]@]@." (action_to_string ctx command)



  let rec help ctx = function
    | Help (Some (Help a)) -> help ctx (Help a)
    | Help (Some a) -> 
      let () = Utils.format "Usage:" in
      let () = print_newline () in
      let () = messages ctx a in
      print_newline ()
    | Help None -> 
      let () = Utils.format "@[<v5>Commands:@[ For@ any@ command,@ its@ usage@ can@ be@ reminded@ by@ running@ the@ following@ command:@]@ @[command help;@]@ @[The@ following@ commands@ are@ available.@]@]@]@." in
      let () = print_newline () in
      List.iter
	(fun a -> 
	  let () = messages ctx a in
	  print_newline ())
	actions
    | _ as a -> 
      let () = Utils.format "Usage:" in
      let () = print_newline () in
      let () = messages ctx a in
      print_newline ()


    
  let load t filename (ctx,e) =
    let includes = (dirs ctx) in
    match t with
    | Data -> 
       (match Data_parser.parse_data ~overwrite:true filename includes e with
	| None -> ctx,e
	| Some e' -> ctx,e') 
    | Object ->
       (let new_env = Env.read filename includes in
	match new_env with
	| Some n_e -> ctx,Env.append e n_e
	| None -> ctx,e)
    | Script f  -> f filename (ctx,e)
    | exception Stop -> ctx,e
       
       
  let list ctx e =
    let _ = Format.flush_str_formatter () in
    let () = Utils.sformat "@[<v3>Available data:@," in
    let () =
      Env.iter
	(function 
	| Env.Signature sg -> Utils.sformat "@[%9s @[%s@]@]@," "Signature" (green ctx (fst (Env.Signature1.name sg)))
	| Env.Lexicon lx -> 
	  let abs_name,obj_name =
	    let abs,obj = Env.Lexicon.get_sig lx in
	    fst (Env.Signature1.name abs),fst (Env.Signature1.name obj) in
	  Utils.sformat 
	    "@[<b>@[%9s @[<3>@[%s@]@ @[(@[%s -->@ %s@])@]@]@]@]@," "Lexicon"
	    (red ctx (fst (Env.Lexicon.name lx)))
	    (green ctx abs_name)
	    (green ctx obj_name))
	e in
    let () = Utils.sformat "@." in
    let s = Format.flush_str_formatter () in
    Utils.format "%s@?" s
   
  let select ctx n l e =
    try
	Env.select n e
    with
      | Env.Signature_not_found n
      | Env.Lexicon_not_found n
      | Env.Entry_not_found n -> raise (Scripting_errors.Error (Scripting_errors.Not_in_environment n,l,ctx.script_filename))

  let unselect = Env.unselect


  let get_entry ctx name e l =
    match name,Env.focus e with
    | None,None -> raise (Scripting_errors.Error (Scripting_errors.No_focus,l,ctx.script_filename))
    | None,Some en -> en
    | Some n,_ ->
      (try 
	 Env.get n e
       with
       | Env.Entry_not_found s -> raise (Scripting_errors.Error (Scripting_errors.Not_in_environment s,l,ctx.script_filename)))
	
  let get_lex ctx name cmd e l =
    match get_entry ctx name e l with
    | Env.Signature sg -> raise (Scripting_errors.Error (Scripting_errors.Accept_only ((Scripting_errors.Lex (fst (Env.Signature1.name sg))),cmd),l,ctx.script_filename))
    | Env.Lexicon lex ->  lex

  let get_sig ctx name cmd e l =
    match get_entry ctx name e l with
    | Env.Lexicon lex -> raise (Scripting_errors.Error (Scripting_errors.Accept_only ((Scripting_errors.Sg (fst (Env.Lexicon.name lex))),cmd),l,ctx.script_filename))
    | Env.Signature sg ->  sg
      
  let get_lexicons ctx names cmd e l =
    match names,Env.focus e with
    | None,None -> raise (Scripting_errors.Error (Scripting_errors.No_focus,l,ctx.script_filename))
    | None,Some (Env.Lexicon lex) -> [lex]
    | None,Some (Env.Signature sg) -> 
       raise Scripting_errors.(Error (Accept_only (Lex (fst (Env.Signature1.name sg)),cmd),l,ctx.script_filename))
    | Some ns,_ -> List.map (fun (n,l) -> get_lex ctx (Some n) cmd e l) ns





  let trace ctx loc = raise (Scripting_errors.(Error (Not_yet_implemented "trace",loc,ctx.script_filename)))
  let dont_trace ctx loc = raise (Scripting_errors.(Error (Not_yet_implemented "don't trace",loc,ctx.script_filename)))

  let print ctx ?name e l =
    try
      let entry =
	match name,Env.focus e with
	  | None,None -> raise (Scripting_errors.Error (Scripting_errors.No_focus,l,ctx.script_filename))
	  | None,Some en -> en
	  | Some n,_ -> Env.get n e
      in
	match entry with
	  | Env.Signature sg -> Format.printf "%s\n%!" (Env.Signature1.to_string sg)
	  | Env.Lexicon lex ->
             Format.printf "%s\n%!" (Env.Lexicon.to_string lex)
    with
      | Env.Signature_not_found n
      | Env.Lexicon_not_found n
      | Env.Entry_not_found n -> raise (Scripting_errors.Error (Scripting_errors.Not_in_environment n,l,ctx.script_filename))



  let in_sg ctx sg = Logs.err (fun m -> m "in signature %s" (green ctx (fst (Env.Signature1.name sg))))

    
  let analyse ctx ?names e data l =
    try
      let () = Printf.printf "\n%!" in
      let _ = Format.flush_str_formatter () in
      let entries =
	match names,Env.focus e with
	| None,None -> raise (Scripting_errors.Error (Scripting_errors.No_focus,l,ctx.script_filename))
	| None,Some en -> [en]
	| Some ns,_ -> 
	  List.map
	    (fun (n,l) -> 
	      try 
		Env.get n e
	      with
	      | Env.Entry_not_found s -> raise (Scripting_errors.Error (Scripting_errors.Not_in_environment s,l,ctx.script_filename)))
	    ns in
      let _ = List.fold_left
	(fun (first,last_abs_sg) entry -> 
	  match entry with
	  | Env.Signature sg -> 
	    (match last_abs_sg with
	    | Some previous_sg when (Env.Signature1.name sg) = (Env.Signature1.name previous_sg) -> (false,last_abs_sg)
	    | _ ->
	      let () = 
		if first then
		  Utils.sformat "@[<v3>@[In@ %s:@]@,@[" (green ctx (fst (Env.Signature1.name sg)))
		else
		  Utils.sformat "@[@["
	      in
	      (match Data_parser.parse_term  ?parsing_context:(Some (data,l)) ~output:true ~color:ctx.colored_output data sg with
	      | None -> let () = in_sg ctx sg in false, Some sg
	      | Some _ -> 
		let () = Utils.sformat "@]@]@." in
		let s = Format.flush_str_formatter () in
		let () = Utils.format "%s@?" s in
		false,None))
	  | Env.Lexicon lex -> 
	    let abs,obj=Env.Lexicon.get_sig lex in
	    match last_abs_sg with
	    |  Some previous_sg when (Env.Signature1.name abs) = (Env.Signature1.name previous_sg) -> (false,last_abs_sg)
	    | _ ->
	      let () =
		if first then
		  Utils.sformat "@[<v3>@[In@ %s:@]@,@[" (green ctx (fst (Env.Signature1.name abs)))
		else
		  Utils.sformat "@[@["
	      in
	      match Data_parser.parse_term  ?parsing_context:(Some (data,l)) ~output:first ~color:ctx.colored_output data abs with
	      | None -> false,Some abs
	      | Some (t,ty) -> 
		let () = Utils.sformat "@]@]@.@." in
		let s = Format.flush_str_formatter () in
		let () = Utils.format "%s" s in
		let t',ty' = Env.Lexicon.interpret t ty lex in
		let () = Utils.sformat "@[<v3>@[Interpreted@ by@ %s@ in@ %s@ as:@]@,@[" 
		  (red ctx (fst (Env.Lexicon.name lex)))
		  (green ctx (fst (Env.Signature1.name obj))) in
		let () = Utils.sformat "@[" in
		let () = Env.Signature1.term_to_formatted_string Format.str_formatter t' obj in
		let () = Utils.sformat "@] :@ @[" in
		let () = Env.Signature1.type_to_formatted_string Format.str_formatter  ty' obj in
		let () = Utils.sformat "@]@]@]@." in
		false,None)
	(true,None)
	entries in
      let () = Utils.sformat "@." in
      let s = Format.flush_str_formatter () in
      Utils.format "%s@?" s
    with
    | Env.Signature_not_found n
    | Env.Lexicon_not_found n
    | Env.Entry_not_found n -> raise (Scripting_errors.Error (Scripting_errors.Not_in_environment n,l,ctx.script_filename))
    | AcgData.Error.Error e ->
       let msg,(_s_pos,e_pos) = AcgData.Error.get_string_error e in
       let string_pos = snd l in
       let new_pos = Lexing.({string_pos with
                               pos_cnum=string_pos.pos_cnum+e_pos.pos_cnum ;
                               pos_lnum=string_pos.pos_lnum+e_pos.pos_lnum ;}) in
       raise (Scripting_errors.Error (Scripting_errors.Parsing msg,(string_pos,new_pos),ctx.script_filename))
      
	
  let toplevel_newline () =
    let () = Printf.printf "\n%!" in
    let _ = Format.flush_str_formatter () in
    ()

  let toplevel_flush_newline () =
    let () = Utils.sformat "@." in
    let s = Format.flush_str_formatter () in
    Utils.format "%s@?" s
 
      
  let check ctx ?names e data l =
    let () = toplevel_newline ()in
    let _ = Format.flush_str_formatter () in
    let signatures =
      match names,Env.focus e with
      | None,None -> raise (Scripting_errors.Error (Scripting_errors.No_focus,l,ctx.script_filename))
      | None,Some (Env.Signature sg) -> [sg]
      | None,Some (Env.Lexicon lex) -> 
	raise (Scripting_errors.Error (
	  Scripting_errors.Accept_only (
	    Scripting_errors.Sg (
	      fst (Env.Lexicon.name lex)),
	    "check"),
	  l,
          ctx.script_filename))
      | Some ns,_ -> List.map (fun (n,l) -> get_sig ctx (Some n) "check" e l) ns in
    try
      let () = List.iter
                 (fun sg -> 
	           let () = Utils.sformat "@[<v3>@[In@ %s:@]@,@[" (green ctx (fst (Env.Signature1.name sg))) in
	           let _ = Data_parser.parse_term  ?parsing_context:(Some (data,l)) ~output:true ~color:ctx.colored_output data sg in
	           let () = Utils.sformat "@]@]@." in
	           let s = Format.flush_str_formatter () in
	           Utils.format "%s" s)
                 signatures in
      toplevel_flush_newline ()
    with
    | AcgData.Error.Error e ->
       let msg,(_s_pos,e_pos) = AcgData.Error.get_string_error e in
       let string_pos = snd l in
       let new_pos = Lexing.({string_pos with
                               pos_cnum=string_pos.pos_cnum+e_pos.pos_cnum ;
                               pos_lnum=string_pos.pos_lnum+e_pos.pos_lnum ;}) in
       raise (Scripting_errors.Error (Scripting_errors.Parsing msg,(string_pos,new_pos),ctx.script_filename))
      

  let realize ctx ?names ?svg_output e data l =
    toplevel_newline ();
    let lexicons = get_lexicons ctx names "realize" e l in
    let _ =
      try
        List.fold_left
          (fun (first,last_abs_sg,last_lex) lex -> 
	    let abs,obj=Env.Lexicon.get_sig lex in
	    let first =
	      match last_abs_sg,last_lex with
	      | None,None  -> 
	         let () = Utils.sformat "@[<v3>@[In@ %s:@]@,@[" (green ctx (fst (Env.Signature1.name abs))) in
                 first
	      | Some previous_sg, Some previous_lex when (Env.Signature1.name abs) <> (Env.Signature1.name previous_sg)  ->
	         let () = Utils.sformat "@,@[<v9>%s @[The@ abstract@ signature@ over@ which@ the@ term@ is@ to@ be@ interpreted@ (below)@ changed.@]" (red ctx "Warning:") in
	         let () = Utils.sformat "@[The@ lexicon@ %s@ has@ %s@ as@ abstract@ vocabulary@ while@ %s@ has@ %s@." (red ctx (fst (Env.Lexicon.name lex))) (green ctx (fst (Env.Signature1.name abs))) (red ctx (fst (Env.Lexicon.name previous_lex))) (green ctx (fst (Env.Signature1.name previous_sg)))in
	         let () = Utils.sformat "@[<v3>@[In@ %s:@]@,@[" (green ctx (fst (Env.Signature1.name abs))) in
                 true
              | Some _,None -> failwith "Bug: previous signature but no previous lexicon"
              | None, Some _ -> failwith "Bug: previous lexicon but no previous signature"
	      | _ ->
                 let () = Utils.sformat "@[@[" in
                 first in
            match Data_parser.parse_term ?parsing_context:(Some (data,l)) ~output:first ~color:ctx.colored_output data abs with
	    | None -> false,Some abs,Some lex
	    | Some (t,ty) -> 
	       let () = Utils.sformat "@]@]@." in
	       let s = Format.flush_str_formatter () in
	       let () = Utils.format "%s" s in
	       let t',ty' = Env.Lexicon.interpret t ty lex in
	       let () = Utils.sformat "@[<v3>@[Interpreted@ by@ %s@ in@ %s@ as:@]@,@[" 
	                  (red ctx (fst (Env.Lexicon.name lex)))
	                  (green ctx (fst (Env.Signature1.name obj))) in
	       let () = Utils.sformat "@[" in
	       let () = Env.Signature1.term_to_formatted_string Format.str_formatter t' obj in
	       let () = Utils.sformat "@] :@ @[" in
	       let () = Env.Signature1.type_to_formatted_string Format.str_formatter  ty' obj in
	       let () = Utils.sformat "@]@]@]@." in
	       let () = match svg_output,first with
	         | None,_ -> ()
	         | Some _,false -> ()
	         | Some filename,true ->
		    let _expanded_t = Logic.Lambda.Lambda.normalize (Env.Signature1.expand_term t abs) in
		    let d = ShowI.realize_diagram t lexicons !config in
	            Diagram.to_svg filename d in
	       false,Some abs,Some lex)
          (true,None,None)
          lexicons
      with
      | AcgData.Error.Error e ->
         let msg,(_s_pos,e_pos) = AcgData.Error.get_string_error e in
         let string_pos = snd l in
         let new_pos = Lexing.({string_pos with
                                 pos_cnum=string_pos.pos_cnum+e_pos.pos_cnum ;
                                 pos_lnum=string_pos.pos_lnum+e_pos.pos_lnum ;}) in
         raise (Scripting_errors.Error (Scripting_errors.Parsing msg,(string_pos,new_pos),ctx.script_filename))
    in
    toplevel_flush_newline ()
    
  let realize_show ?names ?svg_output ctx e data l =
    toplevel_newline ();
    let lexicons = get_lexicons ctx names "realize_show" e l in
    let abs, _ = Env.Lexicon.get_sig (List.hd lexicons) in
    try
      begin
        match Data_parser.parse_term  ?parsing_context:(Some (data,l)) ~color:ctx.colored_output data abs with
        | None -> ()
        | Some (abs_term, _abs_type) ->
           let d = ShowI.realize_diagram abs_term lexicons !config in
           let filename = match svg_output with
	     | None -> "realize.svg"
	     | Some f -> f in
           Diagram.to_svg filename d
      end
    with
    | AcgData.Error.Error e ->
       let msg,(_s_pos,e_pos) = AcgData.Error.get_string_error e in
       let string_pos = snd l in
       let new_pos = Lexing.({string_pos with
                               pos_cnum=string_pos.pos_cnum+e_pos.pos_cnum ;
                               pos_lnum=string_pos.pos_lnum+e_pos.pos_lnum ;}) in
       raise (Scripting_errors.Error (Scripting_errors.Parsing msg,(string_pos,new_pos),ctx.script_filename))

 
  type inputs =
  | Stop
  | Next
  | All

  let return_input s =
    let () = print_newline () in
    match String.lowercase_ascii (String.trim s) with
    | "y" | "yes"-> Some Next
    | "n" | "no" -> Some Stop
    | "a" | "all" -> Some All
    | "" -> Some Next
    | _ -> None


  let rec interact message get_input =
    let () = Printf.printf "%s%!" message in
    match get_input (read_line ()) with
    | Some v -> v
    | None -> interact message get_input
      
  let rec ask_for_next_parse f param =
    let rec no_interaction f p =
      match f p with
      | None -> Logs.app (fun m -> m "@[<v>@,No other solution.@]")
      | Some new_param -> no_interaction f new_param in
    let msg = Printf.sprintf "Do you want to look for another solution?\n\ty/yes\n\tn/no\n\ta/all\n(Default: yes):" in
    match interact msg return_input with
    | Next -> 
      (match f param with
      | None -> Logs.app (fun m -> m "@[<v>@,No other solution.@]")
      | Some new_param when Env.Lexicon.is_empty new_param -> Logs.app (fun m -> m "@[<v>@,No other solution.@]")
      | Some new_param-> ask_for_next_parse f new_param)
    | All -> no_interaction f param
    | Stop -> ()
      

  let get_parse_tree ctx resume abs_ty lex =
    let _ = Format.flush_str_formatter () in
    let abs_sig,_=Env.Lexicon.get_sig lex in
    match Env.Lexicon.get_analysis resume lex with
    | Some t,resume -> 
      let () = Utils.sformat "@[<v>@[An@ antecedent@ by@ %s@ in@ %s@ is:@]@,@[" (red ctx (fst (Env.Lexicon.name lex))) (green ctx (fst (Env.Signature1.name abs_sig))) in
      let () = Utils.sformat "@[@[" in
      let () = Env.Signature1.term_to_formatted_string  Format.str_formatter t abs_sig in
      let () = Utils.sformat "@] :@ @[" in
      let () = Env.Signature1.type_to_formatted_string  Format.str_formatter abs_ty abs_sig in
      let () = Utils.sformat "@]@]@]@]@." in
      let s = Format.flush_str_formatter () in
      let () = Utils.format "%s@?" s in
      Some resume
    | None,_ -> None
      
  let parse ctx ?name e data l =
    let lex = get_lex ctx name "parse" e l in
    try
      begin
        match Data_parser.parse_heterogenous_term ~output:false ~color:ctx.colored_output data lex with
        | None -> ()
        | Some (obj_t,abs_ty) -> 
           let resume = get_parse_tree ctx (Env.Lexicon.parse obj_t abs_ty lex) abs_ty lex in
           match resume with
           | None -> Logs.app (fun m -> m "No solution.")
           | Some resume when Env.Lexicon.is_empty resume -> Logs.app (fun m -> m "@[<v>@,No other solution.@]")
           | Some resume -> ask_for_next_parse (fun res -> get_parse_tree ctx res abs_ty lex) resume
      end
    with
    | AcgData.Error.Error e ->
       let msg,(_s_pos,e_pos) = AcgData.Error.get_string_error e in
       let string_pos = snd l in
       let new_pos = Lexing.({string_pos with
                               pos_cnum=string_pos.pos_cnum+e_pos.pos_cnum ;
                               pos_lnum=string_pos.pos_lnum+e_pos.pos_lnum ;}) in
       raise (Scripting_errors.Error (Scripting_errors.Parsing msg,(string_pos,new_pos),ctx.script_filename))

	  
	  
  let idb ?name ctx e l =
    let lex = get_lex ctx name "query" e l in
    let () = Logs.app (fun m -> m "The datalog program (intensional database) corresponding to the lexicon \"%s\" is:" (fst (Env.Lexicon.name lex))) in
    Env.Lexicon.program_to_log Logs.default Logs.App lex 
	
      
  let query ?name ctx e data l =
    let lex = get_lex ctx name "idb" e l in
    try
      begin
        match Data_parser.parse_heterogenous_term ~output:false ~color:ctx.colored_output data lex with
        | None -> ()
        | Some (obj_t,abs_ty) ->
           let () = Logs.app (fun m -> m
                                         "The datalog program (extensional database) corresponding to the query \"%s\" is:"
	                                 data) in
           Env.Lexicon.query_to_log Logs.default Logs.App obj_t abs_ty lex
      end
    with
    | AcgData.Error.Error e ->
       let msg,(_s_pos,e_pos) = AcgData.Error.get_string_error e in
       let string_pos = snd l in
       let new_pos = Lexing.({string_pos with
                               pos_cnum=string_pos.pos_cnum+e_pos.pos_cnum ;
                               pos_lnum=string_pos.pos_lnum+e_pos.pos_lnum ;}) in
       raise (Scripting_errors.Error (Scripting_errors.Parsing msg,(string_pos,new_pos),ctx.script_filename))
    
    
                               
      
  let entry_name = function
    | Env.Signature sg -> fst (Env.Signature1.name sg)
    | Env.Lexicon lex -> fst (Env.Lexicon.name lex)

  let add ?names ctx e data l =
    try
      let entries,update_focus,foc_name =
	match names,Env.focus e with
	  | None,None -> raise (Scripting_errors.Error (Scripting_errors.No_focus,l,ctx.script_filename))
	  | None,Some en -> [en],true,entry_name en
	  | Some ns,None -> 
	      (List.map (fun (n,l) -> 
			  try 
			    Env.get n e
			  with
			    | Env.Entry_not_found s -> raise (Scripting_errors.Error (Scripting_errors.Not_in_environment s,l,ctx.script_filename))) ns),false,""
	  | Some ns,Some foc -> 
	      let foc_name=entry_name foc in 
		List.fold_left
		  (fun (acc,b,name) (n,l) -> 
		     try 
		       (Env.get n e)::acc,b || n=foc_name,name
		     with
		       | Env.Entry_not_found s -> raise (Scripting_errors.Error (Scripting_errors.Not_in_environment s,l,ctx.script_filename)))
		  ([],false,foc_name)
		  ns in
      let new_env =
	List.fold_left
	  (fun acc entry -> match entry with
	     | Env.Signature sg -> 
		 (match Data_parser.parse_sig_entry ~color:ctx.colored_output data sg acc with
		    | None -> acc
		    | Some new_sg -> Env.insert ~overwrite:true (Env.Signature new_sg) ~to_be_dumped:true acc)
	     | Env.Lexicon lex -> 
		 (match Data_parser.parse_lex_entry ~color:ctx.colored_output data lex acc with
		    | None -> acc
		    | Some new_lex -> Env.insert ~overwrite:true (Env.Lexicon new_lex) ~to_be_dumped:true acc))
	  e
	  entries in
	if update_focus then Env.select foc_name new_env else new_env
    with
      | Env.Signature_not_found n
      | Env.Lexicon_not_found n
      | Env.Entry_not_found n -> raise (Scripting_errors.Error (Scripting_errors.Not_in_environment n,l,ctx.script_filename))
      | AcgData.Error.Error e ->
       let msg,(_s_pos,e_pos) = AcgData.Error.get_string_error e in
       let string_pos = snd l in
       let new_pos = Lexing.({string_pos with
                               pos_cnum=string_pos.pos_cnum+e_pos.pos_cnum ;
                               pos_lnum=string_pos.pos_lnum+e_pos.pos_lnum ;}) in
       raise (Scripting_errors.Error (Scripting_errors.Parsing msg,(string_pos,new_pos),ctx.script_filename))
		
	
	   
  let compose ctx n1 n2 n3 e =
    let get_lex (n,l) =
      try
	Env.get_lexicon n e
      with
	  Env.Lexicon_not_found s -> raise (Scripting_errors.Error (Scripting_errors.No_such_lexicon s,l,ctx.script_filename)) in
    let lex1 = get_lex n1 in
    let lex2 = get_lex n2 in
    let () = Logs.app (fun m -> m "%s = %s o %s\n%!" (fst n3) (fst n1) (fst n2)) in
    Env.insert ~overwrite:true (Env.Lexicon (Env.Lexicon.compose lex1 lex2 n3)) ~to_be_dumped:true e

  let create_sig (n,_) e =
    Env.insert ~overwrite:true (Env.Signature (Env.Signature1.empty (n,(Lexing.dummy_pos,Lexing.dummy_pos)))) ~to_be_dumped:true e


  let get_sig ctx (n,l) e =
    try 
      Env.get_signature n e
    with
      | Env.Signature_not_found s -> raise (Scripting_errors.Error (Scripting_errors.Not_in_environment s,l,ctx.script_filename))
	  
  let create_lex ~abs ~obj ctx (n,_)  e =
    let abs_sg=get_sig ctx abs e in
    let obj_sg=get_sig ctx obj e in
      Env.insert ~overwrite:true (Env.Lexicon (Env.Lexicon.empty ~abs:abs_sg ~obj:obj_sg (n,(Lexing.dummy_pos,Lexing.dummy_pos)) )) ~to_be_dumped:true e


  let save ?names ctx filename e l =
    let entries =
      match names,Env.focus e with
	| None,None -> raise (Scripting_errors.Error (Scripting_errors.No_focus,l,ctx.script_filename))
	| None,Some en -> [en]
	| Some ns,_ ->
           List.map (fun (n,l) -> 
	       try 
		 Env.get n e
	       with
	       | Env.Entry_not_found s -> raise (Scripting_errors.Error (Scripting_errors.Not_in_environment s,l,ctx.script_filename))) ns in
    (* Prot�ger les acc�s avec de bons messages d'erreur *)
    let outch = open_out filename in
    let () = List.iter
               (fun entry ->
	         match entry with
	         | Env.Signature sg -> Printf.fprintf outch "%s\n\n%!" (Env.Signature1.to_string sg)
	         | Env.Lexicon lex -> Printf.fprintf outch "%s\n\n%!" (Env.Lexicon.to_string lex))
               entries in
    close_out outch
                
  let exit () = raise Quit

  let get_filename ctx = ctx.script_filename

  let set_filename name ctx = {ctx with script_filename = name}

end
    
