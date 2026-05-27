---- MODULE SessionStore_TTrace_1779864175 ----
EXTENDS SessionStore, Sequences, TLCExt, SessionStore_TEConstants, Toolbox, Naturals, TLC

_expression ==
    LET SessionStore_TEExpression == INSTANCE SessionStore_TEExpression
    IN SessionStore_TEExpression!expression
----

_trace ==
    LET SessionStore_TETrace == INSTANCE SessionStore_TETrace
    IN SessionStore_TETrace!trace
----

_inv ==
    ~(
        TLCGet("level") = Len(_TETrace)
        /\
        contador = ((r1 :> (u1 :> 2 @@ u2 :> 0 @@ u3 :> 0) @@ r2 :> (u1 :> 0 @@ u2 :> 0 @@ u3 :> 0)))
        /\
        motivos = ((r1 :> (s1 :> "NONE" @@ s2 :> "NONE" @@ s3 :> "NONE") @@ r2 :> (s1 :> "NONE" @@ s2 :> "NONE" @@ s3 :> "NONE")))
        /\
        sessoes = ((r1 :> (s1 :> "NONE" @@ s2 :> "NONE" @@ s3 :> "NONE") @@ r2 :> (s1 :> "NONE" @@ s2 :> "NONE" @@ s3 :> "NONE")))
        /\
        canal = (<<>>)
        /\
        sessaoDe = ((r1 :> (s1 :> "NONE" @@ s2 :> "NONE" @@ s3 :> "NONE") @@ r2 :> (s1 :> "NONE" @@ s2 :> "NONE" @@ s3 :> "NONE")))
        /\
        status = ((r1 :> (u1 :> "OPEN" @@ u2 :> "OPEN" @@ u3 :> "OPEN") @@ r2 :> (u1 :> "OPEN" @@ u2 :> "OPEN" @@ u3 :> "OPEN")))
    )
----

_init ==
    /\ contador = _TETrace[1].contador
    /\ motivos = _TETrace[1].motivos
    /\ sessaoDe = _TETrace[1].sessaoDe
    /\ status = _TETrace[1].status
    /\ sessoes = _TETrace[1].sessoes
    /\ canal = _TETrace[1].canal
----

_next ==
    /\ \E i,j \in DOMAIN _TETrace:
        /\ \/ /\ j = i + 1
              /\ i = TLCGet("level")
        /\ contador  = _TETrace[i].contador
        /\ contador' = _TETrace[j].contador
        /\ motivos  = _TETrace[i].motivos
        /\ motivos' = _TETrace[j].motivos
        /\ sessaoDe  = _TETrace[i].sessaoDe
        /\ sessaoDe' = _TETrace[j].sessaoDe
        /\ status  = _TETrace[i].status
        /\ status' = _TETrace[j].status
        /\ sessoes  = _TETrace[i].sessoes
        /\ sessoes' = _TETrace[j].sessoes
        /\ canal  = _TETrace[i].canal
        /\ canal' = _TETrace[j].canal

\* Uncomment the ASSUME below to write the states of the error trace
\* to the given file in Json format. Note that you can pass any tuple
\* to `JsonSerialize`. For example, a sub-sequence of _TETrace.
    \* ASSUME
    \*     LET J == INSTANCE Json
    \*         IN J!JsonSerialize("SessionStore_TTrace_1779864175.json", _TETrace)

=============================================================================

 Note that you can extract this module `SessionStore_TEExpression`
  to a dedicated file to reuse `expression` (the module in the 
  dedicated `SessionStore_TEExpression.tla` file takes precedence 
  over the module `SessionStore_TEExpression` below).

---- MODULE SessionStore_TEExpression ----
EXTENDS SessionStore, Sequences, TLCExt, SessionStore_TEConstants, Toolbox, Naturals, TLC

expression == 
    [
        \* To hide variables of the `SessionStore` spec from the error trace,
        \* remove the variables below.  The trace will be written in the order
        \* of the fields of this record.
        contador |-> contador
        ,motivos |-> motivos
        ,sessaoDe |-> sessaoDe
        ,status |-> status
        ,sessoes |-> sessoes
        ,canal |-> canal
        
        \* Put additional constant-, state-, and action-level expressions here:
        \* ,_stateNumber |-> _TEPosition
        \* ,_contadorUnchanged |-> contador = contador'
        
        \* Format the `contador` variable as Json value.
        \* ,_contadorJson |->
        \*     LET J == INSTANCE Json
        \*     IN J!ToJson(contador)
        
        \* Lastly, you may build expressions over arbitrary sets of states by
        \* leveraging the _TETrace operator.  For example, this is how to
        \* count the number of times a spec variable changed up to the current
        \* state in the trace.
        \* ,_contadorModCount |->
        \*     LET F[s \in DOMAIN _TETrace] ==
        \*         IF s = 1 THEN 0
        \*         ELSE IF _TETrace[s].contador # _TETrace[s-1].contador
        \*             THEN 1 + F[s-1] ELSE F[s-1]
        \*     IN F[_TEPosition - 1]
    ]

=============================================================================



Parsing and semantic processing can take forever if the trace below is long.
 In this case, it is advised to uncomment the module below to deserialize the
 trace from a generated binary file.

\*
\*---- MODULE SessionStore_TETrace ----
\*EXTENDS SessionStore, IOUtils, SessionStore_TEConstants, TLC
\*
\*trace == IODeserialize("SessionStore_TTrace_1779864175.bin", TRUE)
\*
\*=============================================================================
\*

---- MODULE SessionStore_TETrace ----
EXTENDS SessionStore, SessionStore_TEConstants, TLC

trace == 
    <<
    ([contador |-> (r1 :> (u1 :> 0 @@ u2 :> 0 @@ u3 :> 0) @@ r2 :> (u1 :> 0 @@ u2 :> 0 @@ u3 :> 0)),motivos |-> (r1 :> (s1 :> "NONE" @@ s2 :> "NONE" @@ s3 :> "NONE") @@ r2 :> (s1 :> "NONE" @@ s2 :> "NONE" @@ s3 :> "NONE")),sessoes |-> (r1 :> (s1 :> "NONE" @@ s2 :> "NONE" @@ s3 :> "NONE") @@ r2 :> (s1 :> "NONE" @@ s2 :> "NONE" @@ s3 :> "NONE")),canal |-> <<>>,sessaoDe |-> (r1 :> (s1 :> "NONE" @@ s2 :> "NONE" @@ s3 :> "NONE") @@ r2 :> (s1 :> "NONE" @@ s2 :> "NONE" @@ s3 :> "NONE")),status |-> (r1 :> (u1 :> "OPEN" @@ u2 :> "OPEN" @@ u3 :> "OPEN") @@ r2 :> (u1 :> "OPEN" @@ u2 :> "OPEN" @@ u3 :> "OPEN"))]),
    ([contador |-> (r1 :> (u1 :> 1 @@ u2 :> 0 @@ u3 :> 0) @@ r2 :> (u1 :> 0 @@ u2 :> 0 @@ u3 :> 0)),motivos |-> (r1 :> (s1 :> "NONE" @@ s2 :> "NONE" @@ s3 :> "NONE") @@ r2 :> (s1 :> "NONE" @@ s2 :> "NONE" @@ s3 :> "NONE")),sessoes |-> (r1 :> (s1 :> "NONE" @@ s2 :> "NONE" @@ s3 :> "NONE") @@ r2 :> (s1 :> "NONE" @@ s2 :> "NONE" @@ s3 :> "NONE")),canal |-> <<[tipo |-> "CONTADOR_INC", chave |-> u1, payload |-> ""]>>,sessaoDe |-> (r1 :> (s1 :> "NONE" @@ s2 :> "NONE" @@ s3 :> "NONE") @@ r2 :> (s1 :> "NONE" @@ s2 :> "NONE" @@ s3 :> "NONE")),status |-> (r1 :> (u1 :> "OPEN" @@ u2 :> "OPEN" @@ u3 :> "OPEN") @@ r2 :> (u1 :> "OPEN" @@ u2 :> "OPEN" @@ u3 :> "OPEN"))]),
    ([contador |-> (r1 :> (u1 :> 2 @@ u2 :> 0 @@ u3 :> 0) @@ r2 :> (u1 :> 0 @@ u2 :> 0 @@ u3 :> 0)),motivos |-> (r1 :> (s1 :> "NONE" @@ s2 :> "NONE" @@ s3 :> "NONE") @@ r2 :> (s1 :> "NONE" @@ s2 :> "NONE" @@ s3 :> "NONE")),sessoes |-> (r1 :> (s1 :> "NONE" @@ s2 :> "NONE" @@ s3 :> "NONE") @@ r2 :> (s1 :> "NONE" @@ s2 :> "NONE" @@ s3 :> "NONE")),canal |-> <<>>,sessaoDe |-> (r1 :> (s1 :> "NONE" @@ s2 :> "NONE" @@ s3 :> "NONE") @@ r2 :> (s1 :> "NONE" @@ s2 :> "NONE" @@ s3 :> "NONE")),status |-> (r1 :> (u1 :> "OPEN" @@ u2 :> "OPEN" @@ u3 :> "OPEN") @@ r2 :> (u1 :> "OPEN" @@ u2 :> "OPEN" @@ u3 :> "OPEN"))])
    >>
----


=============================================================================

---- MODULE SessionStore_TEConstants ----
EXTENDS SessionStore

CONSTANTS u1, u2, u3, s1, s2, s3, r1, r2

=============================================================================

---- CONFIG SessionStore_TTrace_1779864175 ----
CONSTANTS
    IDS = { u1 , u2 , u3 }
    SIDS = { s1 , s2 , s3 }
    REPLICAS = { r1 , r2 }
    LIMITE = 3
    r2 = r2
    u3 = u3
    u2 = u2
    u1 = u1
    s1 = s1
    r1 = r1
    s3 = s3
    s2 = s2

INVARIANT
    _inv

CHECK_DEADLOCK
    \* CHECK_DEADLOCK off because of PROPERTY or INVARIANT above.
    FALSE

INIT
    _init

NEXT
    _next

CONSTANT
    _TETrace <- _trace

ALIAS
    _expression
=============================================================================
\* Generated on Tue May 26 23:42:56 PDT 2026