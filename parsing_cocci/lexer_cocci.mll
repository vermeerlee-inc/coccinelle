{
open Parser_cocci_menhir
module D = Data
module Ast = Ast_cocci
exception Lexical of string
let tok = Lexing.lexeme

let line = ref 1
let logical_line = ref 0

(* ---------------------------------------------------------------------- *)
(* control codes *)

(* Defined in data.ml
type line_type = MINUS | OPTMINUS | UNIQUEMINUS | PLUS | CONTEXT | UNIQUE | OPT
*)

let in_atat = ref false

let current_line_type = ref (D.CONTEXT,!line,!logical_line)
let get_current_line_type lexbuf =
  let (c,l,ll) = !current_line_type in (c,l,ll,Lexing.lexeme_start lexbuf)
let current_line_started = ref false

let reset_line _ =
  line := !line + 1;
  current_line_type := (D.CONTEXT,!line,!logical_line);
  current_line_started := false

let started_line = ref (-1)

let start_line seen_char =
  current_line_started := true;
  if seen_char && not(!line = !started_line)
  then
    begin
      started_line := !line;
      logical_line := !logical_line + 1
    end

let add_current_line_type x =
  match (x,!current_line_type) with
    (D.MINUS,(D.CONTEXT,ln,lln))  ->
      current_line_type := (D.MINUS,ln,lln)
  | (D.MINUS,(D.UNIQUE,ln,lln))   ->
      current_line_type := (D.UNIQUEMINUS,ln,lln)
  | (D.MINUS,(D.OPT,ln,lln))      ->
      current_line_type := (D.OPTMINUS,ln,lln)
  | (D.MINUS,(D.MULTI,ln,lln))      ->
      current_line_type := (D.MULTIMINUS,ln,lln)
  | (D.PLUS,(D.CONTEXT,ln,lln))   ->
      current_line_type := (D.PLUS,ln,lln)
  | (D.UNIQUE,(D.CONTEXT,ln,lln)) ->
      current_line_type := (D.UNIQUE,ln,lln)
  | (D.OPT,(D.CONTEXT,ln,lln))    ->
      current_line_type := (D.OPT,ln,lln)
  | (D.MULTI,(D.CONTEXT,ln,lln))    ->
      current_line_type := (D.MULTI,ln,lln)
  | _ -> raise (Lexical "invalid control character combination")

let check_minus_context_linetype s =
  match !current_line_type with
    (D.PLUS,_,_) -> raise (Lexical ("invalid in a + context:"^s))
  | _ -> ()

let check_context_linetype s =
  match !current_line_type with
    (D.CONTEXT,_,_) -> ()
  | _ -> raise (Lexical ("invalid in a nonempty context:"^s))

let check_arity_context_linetype s =
  match !current_line_type with
    (D.CONTEXT,_,_) | (D.PLUS,_,_) | (D.UNIQUE,_,_) | (D.OPT,_,_) -> ()
  | _ -> raise (Lexical ("invalid in a nonempty context:"^s))

(* ---------------------------------------------------------------------- *)
(* identifiers, including metavariables *)

let metavariables =
  (Hashtbl.create(100) :
     (string, D.line_type * int * int * int -> token) Hashtbl.t)

let id_tokens lexbuf =
  let s = tok lexbuf in
  match s with
    "identifier" -> check_arity_context_linetype s; TIdentifier
  | "type" ->       check_arity_context_linetype s; TType
  | "parameter" ->  check_arity_context_linetype s; TParameter
  | "constant"  ->  check_arity_context_linetype s; TConstant
  | "expression" -> check_arity_context_linetype s; TExpression
  | "statement" ->  check_arity_context_linetype s; TStatement
  | "function"  ->  check_arity_context_linetype s; TFunction
  | "local" ->      check_arity_context_linetype s; TLocal
  | "list" ->       check_arity_context_linetype s; Tlist
  | "fresh" ->      check_arity_context_linetype s; TFresh
  | "error" ->      check_arity_context_linetype s; TError
  | "words" ->      check_context_linetype s; TWords

  | "char" ->       Tchar   (get_current_line_type lexbuf)
  | "short" ->      Tshort  (get_current_line_type lexbuf)
  | "int" ->        Tint    (get_current_line_type lexbuf)
  | "double" ->     Tdouble (get_current_line_type lexbuf)
  | "float" ->      Tfloat  (get_current_line_type lexbuf)
  | "long" ->       Tlong   (get_current_line_type lexbuf)
  | "void" ->       Tvoid   (get_current_line_type lexbuf)
  | "struct" ->     Tstruct (get_current_line_type lexbuf)
  | "union" ->      Tunion  (get_current_line_type lexbuf)
  | "unsigned" ->   Tunsigned (get_current_line_type lexbuf)
  | "signed" ->     Tsigned (get_current_line_type lexbuf)
	
  | "static" ->     Tstatic (get_current_line_type lexbuf)
  | "const" ->      Tconst  (get_current_line_type lexbuf)
  | "volatile" ->   Tstatic (get_current_line_type lexbuf)

  | "if" ->         TIf     (get_current_line_type lexbuf)
  | "else" ->       TElse   (get_current_line_type lexbuf)
  | "while" ->      TWhile  (get_current_line_type lexbuf)
  | "do" ->         TDo     (get_current_line_type lexbuf)
  | "for" ->        TFor    (get_current_line_type lexbuf)
  | "return" ->     TReturn (get_current_line_type lexbuf)
  | "break" ->      TBreak  (get_current_line_type lexbuf)
  | "continue" ->   TContinue (get_current_line_type lexbuf)

  | "sizeof" ->     TSizeof (get_current_line_type lexbuf)

  | "Expression"     -> TIsoExpression
  | "Statement"      -> TIsoStatement
  | "Declaration"    -> TIsoDeclaration

  | s ->
      try (Hashtbl.find metavariables s) (get_current_line_type lexbuf)
      with Not_found -> TIdent (s,(get_current_line_type lexbuf))

let mkassign op lexbuf =
  TAssign (Ast.OpAssign op, (get_current_line_type lexbuf))

let init _ =
  line := 1;
  logical_line := 0;
  in_atat := false;
  Data.clear_meta := (function _ -> Hashtbl.clear metavariables);
  Data.add_id_meta :=
    (let fn name clt = TMetaId(name,clt) in
    (function name -> Hashtbl.replace metavariables name (fn name)));
  Data.add_type_meta :=
    (let fn name clt = TMetaType(name,clt) in
    (function name -> Hashtbl.replace metavariables name (fn name)));
  Data.add_param_meta :=
    (let fn name clt = TMetaParam(name,clt) in
    (function name -> Hashtbl.replace metavariables name (fn name)));
  Data.add_paramlist_meta :=
    (let fn name clt = TMetaParamList(name,clt) in
    (function name -> Hashtbl.replace metavariables name (fn name)));
  Data.add_const_meta :=
    (let fn tyopt name clt = TMetaConst(name,tyopt,clt) in
    (function tyopt -> function name -> 
      Hashtbl.replace metavariables name (fn tyopt name)));
  Data.add_err_meta :=
    (let fn name clt = TMetaErr(name,clt) in
    (function name -> Hashtbl.replace metavariables name (fn name)));
  Data.add_exp_meta :=
    (let fn tyopt name clt = TMetaExp(name,tyopt,clt) in
    (function tyopt -> function name ->
      Hashtbl.replace metavariables name (fn tyopt name)));
  Data.add_explist_meta :=
    (let fn name clt = TMetaExpList(name,clt) in
    (function name -> Hashtbl.replace metavariables name (fn name)));
  Data.add_stm_meta :=
    (let fn name clt = TMetaStm(name,clt) in
    (function name -> Hashtbl.replace metavariables name (fn name)));
  Data.add_stmlist_meta :=
    (let fn name clt = TMetaStmList(name,clt) in
    (function name -> Hashtbl.replace metavariables name (fn name)));
  Data.add_func_meta :=
    (let fn name clt = TMetaFunc(name,clt) in
    (function name -> Hashtbl.replace metavariables name (fn name)));
  Data.add_local_func_meta :=
    (let fn name clt = TMetaLocalFunc(name,clt) in
    (function name -> Hashtbl.replace metavariables name (fn name)))

let drop_spaces s =
  let len = String.length s in
  let rec loop n =
    if n = len
    then n
    else
      if List.mem (String.get s n) [' ';'\t']
      then loop (n+1)
      else n in
  let start = loop 0 in
  String.sub s start (len - start)
}

(* ---------------------------------------------------------------------- *)
(* tokens *)

let letter = ['A'-'Z' 'a'-'z' '_']
let digit  = ['0'-'9']

let dec = ['0'-'9']
let oct = ['0'-'7']
let hex = ['0'-'9' 'a'-'f' 'A'-'F']

let decimal = ('0' | (['1'-'9'] dec*))
let octal   = ['0']        oct+
let hexa    = ("0x" |"0X") hex+ 

let pent   = dec+
let pfract = dec+
let sign = ['-' '+']
let exp  = ['e''E'] sign? dec+
let real = pent exp | ((pent? '.' pfract | pent '.' pfract? ) exp?)


rule token = parse
  | [' ' '\t'  ]+             { start_line false; token lexbuf }
  | ['\n' '\r' '\011' '\012'] { reset_line(); token lexbuf }

  | "//" [^ '\n']* { start_line false; token lexbuf }

  | "@@" { start_line true; in_atat := not(!in_atat); TArobArob }

  | "WHEN" | "when"
      { start_line true; check_minus_context_linetype (tok lexbuf);
	TWhen (get_current_line_type lexbuf) }

  | "..."
      { start_line true; check_minus_context_linetype (tok lexbuf);
	TEllipsis (get_current_line_type lexbuf) }

  | "ooo"
      { start_line true; check_minus_context_linetype (tok lexbuf);
	TCircles (get_current_line_type lexbuf) }

  | "***"
      { start_line true; check_minus_context_linetype (tok lexbuf);
	TStars (get_current_line_type lexbuf) }

  | "<..." { start_line true; check_context_linetype (tok lexbuf);
	     TOEllipsis (get_current_line_type lexbuf) }
  | "...>" { start_line true; check_context_linetype (tok lexbuf);
	     TCEllipsis (get_current_line_type lexbuf) }

  | "<ooo" { start_line true; check_context_linetype (tok lexbuf);
	     TOCircles (get_current_line_type lexbuf) }
  | "ooo>" { start_line true; check_context_linetype (tok lexbuf);
	     TCCircles (get_current_line_type lexbuf) }

  | "<***" { start_line true; check_context_linetype (tok lexbuf);
	     TOStars (get_current_line_type lexbuf) }
  | "***>" { start_line true; check_context_linetype (tok lexbuf);
	     TCStars (get_current_line_type lexbuf) }

  | "-" { if !current_line_started
	  then (start_line true; TMinus (get_current_line_type lexbuf))
          else (add_current_line_type D.MINUS; token lexbuf) }
  | "+" { if !current_line_started
	  then (start_line true; TPlus (get_current_line_type lexbuf))
          else if !in_atat
	  then TPlus0
          else (add_current_line_type D.PLUS; token lexbuf) }
  | "\\+" { if !current_line_started
	  then failwith "Illegal use of \\+"
          else if !in_atat
	  then TPlus0
          else (add_current_line_type D.MULTI; token lexbuf) }
  | "?" { if !current_line_started
	  then (start_line true; TWhy (get_current_line_type lexbuf))
          else if !in_atat
	  then TWhy0
          else (add_current_line_type D.OPT; token lexbuf) }
  | "!" { if !current_line_started
	  then (start_line true; TBang (get_current_line_type lexbuf))
          else if !in_atat
	  then TBang0
          else (add_current_line_type D.UNIQUE; token lexbuf) }
  | "(" { if !current_line_started
	  then (start_line true; TOPar (get_current_line_type lexbuf))
          else
            (start_line true; check_context_linetype (tok lexbuf);
	     TOPar0 (get_current_line_type lexbuf))}
  | "|" { if !current_line_started
	  then (start_line true; TOr (get_current_line_type lexbuf))
          else (start_line true;
		check_context_linetype (tok lexbuf);
		TMid0 (get_current_line_type lexbuf))}
  | ")" { if !current_line_started
	  then (start_line true; TCPar (get_current_line_type lexbuf))
          else
            (start_line true; check_context_linetype (tok lexbuf);
	     TCPar0 (get_current_line_type lexbuf))}

  | '[' { start_line true; TOCro (get_current_line_type lexbuf) }
  | ']' { start_line true; TCCro (get_current_line_type lexbuf) }
  | '{' { start_line true; TOBrace (get_current_line_type lexbuf) }
  | '}' { start_line true; TCBrace (get_current_line_type lexbuf) }

  | "->"           { start_line true; TPtrOp (get_current_line_type lexbuf) }
  | '.'            { start_line true; TDot (get_current_line_type lexbuf) }
  | ','            { start_line true; TComma (get_current_line_type lexbuf) }
  | ";"            { start_line true; TPtVirg (get_current_line_type lexbuf) }

  
  | '*'            { start_line true;  TMul (get_current_line_type lexbuf) }     
  | '/'            { start_line true;  TDiv (get_current_line_type lexbuf) } 
  | '%'            { start_line true;  TMod (get_current_line_type lexbuf) } 
  
  | "++"           { start_line true;  TInc (get_current_line_type lexbuf) }    
  | "--"           { start_line true;  TDec (get_current_line_type lexbuf) }
  
  | "="            { start_line true; TEq (get_current_line_type lexbuf) } 
  
  | "-="           { start_line true; mkassign Ast.Minus lexbuf }
  | "+="           { start_line true; mkassign Ast.Plus lexbuf }
  
  | "*="           { start_line true; mkassign Ast.Mul lexbuf }
  | "/="           { start_line true; mkassign Ast.Div lexbuf }
  | "%="           { start_line true; mkassign Ast.Mod lexbuf }
  
  | "&="           { start_line true; mkassign Ast.And lexbuf }
  | "|="           { start_line true; mkassign Ast.Or lexbuf }
  | "^="           { start_line true; mkassign Ast.Xor lexbuf }
  
  | "<<="          { start_line true; mkassign Ast.DecLeft lexbuf }
  | ">>="          { start_line true; mkassign Ast.DecRight lexbuf }

  | ":"            { start_line true; TDotDot (get_current_line_type lexbuf) }
  
  | "=="           { start_line true; TEqEq   (get_current_line_type lexbuf) }   
  | "!="           { start_line true; TNotEq  (get_current_line_type lexbuf) } 
  | ">="           { start_line true; TInfEq  (get_current_line_type lexbuf) } 
  | "<="           { start_line true; TSupEq  (get_current_line_type lexbuf) } 
  | "<"            { start_line true; TInf    (get_current_line_type lexbuf) } 
  | ">"            { start_line true; TSup    (get_current_line_type lexbuf) }
  
  | "&&"           { start_line true; TAndLog (get_current_line_type lexbuf) } 
  | "||"           { start_line true; TOrLog  (get_current_line_type lexbuf) }
  
  | ">>"           { start_line true; TShr    (get_current_line_type lexbuf) }
  | "<<"           { start_line true; TShl    (get_current_line_type lexbuf) }
  
  | "&"            { start_line true; TAnd    (get_current_line_type lexbuf) }
  | "^"            { start_line true; TXor    (get_current_line_type lexbuf) }

  | "#" [' ' '\t']* "include" [' ' '\t']* '"' [^ '"']+ '"'
      { TInclude
	  (let str = tok lexbuf in
	  let start = String.index str '"' in
	  let finish = String.rindex str '"' in
	  start_line true;
	  (String.sub str start (finish - start + 1),
	   (get_current_line_type lexbuf))) }
  | "#" [' ' '\t']* "include" [' ' '\t']* '<' [^ '>']+ '>'
      { TInclude
	  (let str = tok lexbuf in
	  let start = String.index str '<' in
	  let finish = String.rindex str '>' in
	  start_line true;
	  (String.sub str start (finish - start + 1),
	   (get_current_line_type lexbuf)))}
  | "---" [^'\n']*
      { (if !current_line_started
      then failwith "--- must be at the beginning of the line");
	start_line true;
	TMinusFile
	  (let str = tok lexbuf in
	  (drop_spaces(String.sub str 3 (String.length str - 3)),
	   (get_current_line_type lexbuf))) }
  | "+++" [^'\n']*
      { (if !current_line_started
      then failwith "--- must be at the beginning of the line");
	start_line true;
	TPlusFile
	  (let str = tok lexbuf in
	  (drop_spaces(String.sub str 3 (String.length str - 3)),
	   (get_current_line_type lexbuf))) }

  | letter (letter | digit)*
      { start_line true; id_tokens lexbuf } 

  | "'" { start_line true;
	  TChar(char lexbuf,(get_current_line_type lexbuf)) }
  | '"' { start_line true;
	  TString(string lexbuf,(get_current_line_type lexbuf)) }
  | (real as x)    { start_line true;
		     TFloat(x,(get_current_line_type lexbuf)) }
  | (decimal as x) { start_line true; TInt(x,(get_current_line_type lexbuf)) }

  | "<=>"          { TIso }
  | "=>"           { TRightIso }

  | eof            { EOF }

  | _ { raise (Lexical ("unrecognised symbol, in token rule:"^tok lexbuf)) }


and char = parse
  | (_ as x) "'"                                     { String.make 1 x }
  | (("\\" (oct | oct oct | oct oct oct)) as x  "'") { x }
  | (("\\x" (hex | hex hex)) as x  "'")       { x }
  | (("\\" (_ as v)) as x "'")
	{ (match v with
            | 'n' -> ()  | 't' -> ()   | 'v' -> ()  | 'b' -> ()
	    | 'r' -> ()  | 'f' -> () | 'a' -> ()
	    | '\\' -> () | '?'  -> () | '\'' -> ()  | '"' -> ()
            | 'e' -> ()
	    | _ -> raise (Lexical ("unrecognised symbol:"^tok lexbuf))
	    );
          x
	} 
  | _ { raise (Lexical ("unrecognised symbol:"^tok lexbuf)) }

and string  = parse
  | '"'                                       { "" }
  | (_ as x)                   { Common.string_of_char x ^ string lexbuf }
  | ("\\" (oct | oct oct | oct oct oct)) as x { x ^ string lexbuf }
  | ("\\x" (hex | hex hex)) as x              { x ^ string lexbuf }
  | ("\\" (_ as v)) as x  
       { 
         (match v with
         | 'n' -> ()  | 't' -> ()   | 'v' -> ()  | 'b' -> () | 'r' -> () 
	 | 'f' -> () | 'a' -> ()
	 | '\\' -> () | '?'  -> () | '\'' -> ()  | '"' -> ()
         | 'e' -> ()
         | '\n' -> () 
         | _ -> raise (Lexical ("unrecognised symbol:"^tok lexbuf))
	 );
          x ^ string lexbuf
       }
  | _ { raise (Lexical ("unrecognised symbol:"^tok lexbuf)) }
