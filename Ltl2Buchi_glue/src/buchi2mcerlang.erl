%% Copyright (c) 2009, Lars-Ake Fredlund, Hans Svensson
%% All rights reserved.
%%
%% Redistribution and use in source and binary forms, with or without
%% modification, are permitted provided that the following conditions are met:
%%     %% Redistributions of source code must retain the above copyright
%%       notice, this list of conditions and the following disclaimer.
%%     %% Redistributions in binary form must reproduce the above copyright
%%       notice, this list of conditions and the following disclaimer in the
%%       documentation and/or other materials provided with the distribution.
%%     %% Neither the name of the copyright holders nor the
%%       names of its contributors may be used to endorse or promote products
%%       derived from this software without specific prior written permission.
%%
%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ''AS IS''
%% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
%% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
%% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
%% BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
%% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
%% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR 
%% BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
%% WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR 
%% OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF 
%% ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

-module(buchi2mcerlang).

-export([new/0,add_state/3,add_transition/4]).
-export([pred_condition/1,neg_condition/1,and_condition/2,
	 boolean_condition/1,or_condition/2,
	 to_mcerlang_monitor/3]).

new() -> digraph:new().

add_state(Name,Attributes,G) ->  %% Attributes = initial|accepting
  State = {state,{Name,Attributes}},
  digraph:add_vertex(G,Name,State),
  G.

add_transition(FromState,Condition,ToState,G) ->
  Transition = {transition,{FromState,Condition,ToState}},
  digraph:add_edge(G,FromState,ToState,Transition),
  G.

pred_condition(Predicate) ->
  case Predicate of
    true -> boolean_condition(true);
    false -> boolean_condition(false);
    _ -> {pred,Predicate}
  end.

neg_condition(Condition) ->
  {cnot,Condition}.

and_condition(Condition1,Condition2) ->
  {cand,{Condition1,Condition2}}.

or_condition(Condition1,Condition2) ->
  neg_condition
    (and_condition(neg_condition(Condition1),neg_condition(Condition2))).

boolean_condition(Boolean) ->
  {bool,Boolean}.

to_mcerlang_monitor(LTLFormulaString,G,FileName) ->
  {ok,File} = file:open(FileName,[write]),
  io:format
    (File,
     "%% Automatically generated by buchi2mcerlang:to_mcerlang_monitor~n"++
     "%% applied to the LTL formula ~s~n~n",
     [LTLFormulaString]),
  ModuleName = filename:rootname(filename:basename(FileName)),
  io:format(File,"-module("++ModuleName++").~n",[]),
  io:format(File,"-language(erlang).~n",[]),
  io:format(File,"-behaviour(mce_behav_monitor).~n~n",[]),
  io:format
    (File,
     "-export([init/1,stateChange/3,monitorType/0,stateType/1]).~n~n",
     []),
  io:format(File,"monitorType() -> buechi.~n~n",[]),
  AllPredicateVars = returnPredicateVars(G),
  {NumInitialStates,InitialState} = 
    case initialState(G) of
      {ok,IState} -> {1,IState};
      _ -> {0,1}
    end,
  io:format
    (File,"init(PState) ->~n",
     []),
  case AllPredicateVars of
    [] ->
      io:format
	(File,
	 "~s{ok,{~p,{PState,mce_buechi_gen:parse_predspec([],[])}}}.~n~n",
	 [indent(2),InitialState]);
    _ ->
      io:format
	(File,"~s{Priv,PredSpec}=PState,~n",[indent(2)]),
      io:format
	(File,
	 "~s{ok,{~p,{Priv,mce_buechi_gen:parse_predspec([~s],PredSpec)}}}.~n~n",
	 [indent(2),InitialState,
	  printCommaList(lists:map(fun print_atom/1,AllPredicateVars))])
  end,
  io:format
    (File,
     "stateChange(State,{MonState,{PrivateState,Predicates}},Stack) ->~n",[]),
  io:format(File,"~s{Entry,_} = mce_behav_stackOps:pop(Stack),~n",[indent(2)]),
  io:format(File,"~sActions = mce_buechi_gen:actions(Entry),~n",[indent(2)]),
  case NumInitialStates of
    0 ->
      io:format(File,"~s[].~n",[indent(2)]),
      io:format(File,"~nstateType(1) -> nonaccepting.~n",[]);
    _ ->
      io:format(File,"~scase MonState of~n",[indent(2)]),
      AlternativesStr =
	lists:map
	  (fun ({_,{state,{Name,_}}}) ->
	       io_lib:format("~s~p ->~n",[indent(4),Name])++
		 io_lib:format("~smce_buechi_gen:combine~n~s([",
			       [indent(6),indent(8)])++
		 io_lib:format
		   ("~s],Predicates)~n",
		    [printArgs
		       (lists:map
			  (fun ({_,{transition,{_,Condition,ToState}}}) ->
			       io_lib:format
				 ("mce_buechi_gen:ccond(State,Actions,"++
				    "PrivateState,~s,~p)",
				  [printCondition(Condition,AllPredicateVars),
				   ToState])
			   end,
			   transitionsFrom(Name,G)),
			fun () -> io_lib:format(",~n~s",[indent(10)]) end)])
	   end,
	   allVertices(G)),
      io:format
	(File,"~s~n~send.~n~n",
	 [printArgs(AlternativesStr,fun () -> io_lib:format(";~n",[]) end),
	  indent(2)]),
      io:format
	(File,
	 "~s.~n~n",
	 [printArgs
	    (lists:map
	       (fun ({_,{state,{Name,Attributes}}}) ->
		    io_lib:format("stateType(~p) -> ~p",
				  [Name,
				   case lists:member(accepting,Attributes) of
				     true -> accepting;
				     false -> nonaccepting
				   end])
		end,allVertices(G)),
	     fun () -> io_lib:format(";~n",[]) end)])
  end,
  file:close(File).

printCondition({pred,A},AllPredicateVars) ->
  io_lib:format("{pred,~s}",[pred(A,AllPredicateVars)]);
printCondition({cnot,Cond},AllPredicateVars) ->
  io_lib:format("{cnot,~s}",[printCondition(Cond,AllPredicateVars)]);
printCondition({cand,{Cond1,Cond2}},AllPredicateVars) ->
  io_lib:format
    ("{cand,{~s,~s}}",
     [printCondition(Cond1,AllPredicateVars),
      printCondition(Cond2,AllPredicateVars)]);
printCondition({bool,Bool},_AllPredicateVars) -> 
  io_lib:format("{bool,~s}",[atom_to_list(Bool)]).

pred({var,V},AllPredicateVars) ->
  gen_element(V,AllPredicateVars,1);
pred({Module,Fun},_AllPredicateVars) ->
  io_lib:format("{~p,~p}",[Module,Fun]);
pred(Fun,AllPredicateVars) when is_function(Fun) ->
  {module,Module} = erlang:fun_info(Fun,module),
  {name,Name} = erlang:fun_info(Fun,name),
  {arity,_Arity} = erlang:fun_info(Fun,arity),
  case erlang:fun_info(Fun,pid) of
    {pid,undefined} -> 
      pred({Module,Name},AllPredicateVars);
    {pid,_} -> 
      io:format
      ("Cannot translate local proposition function ~p~n",
       [Fun]),
      throw(buchi_exc)
  end.

gen_element(V,[V|_],N) ->
  io_lib:format("element(~p,Predicates)",[N]);
gen_element(V,[_|Rest],N) ->
  gen_element(V,Rest,N+1).

indent(0) -> "";
indent(N) when N>0 -> " "++indent(N-1).

printArgs([],_Combinator) ->
  "";
printArgs([T],_Combinator) ->
  io_lib:format("~s",[T]);
printArgs([T|Rest],Combinator) ->
  io_lib:format("~s~s~s",[T,Combinator(),printArgs(Rest,Combinator)]).

transitionsFrom(State,G) ->
  lists:filter
    (fun ({_,{transition,{FromState,_,_}}}) ->
	 FromState=:=State
     end, allEdges(G)).

allVertices(G) ->
  lists:map
    (fun (V) -> digraph:vertex(G,V) end,
     digraph:vertices(G)).

allEdges(G) ->
  lists:map
    (fun (E) -> {E,_,_,Label} = digraph:edge(G,E), {E,Label} end,
     digraph:edges(G)).

initialState(G) ->
  case lists:filter(fun ({_,{state,{_,Attributes}}}) ->
			lists:member(initial,Attributes)
		    end, allVertices(G)) of
    [{_,{state,{Name,_}}}] ->
      {ok,Name};
    [] ->
      no;
    Other ->
      io:format("No (or multiple initialstates) in graph: ~p~n",[Other]),
      exit(initialState)
  end.

returnPredicateVars(G) ->
  lists:foldl
    (fun ({_,{transition,{_,Condition,_}}},Ps) ->
	 Preds = returnPreds(Condition),
	 lists:umerge(Preds,Ps)
     end, [], allEdges(G)).

returnPreds(Condition) ->
  case Condition of
    {pred,{var,V}} ->
      [V];
    {cnot,Cnd} ->
      returnPreds(Cnd);
    {cand,{Cnd1,Cnd2}} ->
      lists:umerge(returnPreds(Cnd1),returnPreds(Cnd2));
    {cor,{Cnd1,Cnd2}} ->
      lists:umerge(returnPreds(Cnd1),returnPreds(Cnd2));
    _ ->
      []
  end.

printCommaList(L) ->
  printArgs(L,fun () -> "," end).

print_atom(A) ->
  io_lib:format("~p",[A]).
