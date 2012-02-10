-module(dining_run).
-compile(export_all).

-include("mce_opts.hrl").


mc(N) when N>0, is_integer(N) ->
  mce:start
    (#mce_opts
     {program={dining,start,[N]},
      is_infinitely_fast=false,
      table=mce_table_hashWithActions,
      sends_are_sefs=true,
      shortest=true,
      save_table=true,
      discrete_time=true}).

dot(N) ->
  mc(N),
  file:write_file
    ("hej.dot",
     mce_dot:from_table
     (mce_result:table(mce:result()),
      void,
      fun print_actions/1)).

mc2(N) when N>0, is_integer(N) ->
  mce:start
    (#mce_opts
     {program={dining,start,[N]},
      is_infinitely_fast=false,
      table=mce_table_hashWithActions,
      sends_are_sefs=true,
      shortest=true,
      well_behaved=true,
      partial_order=true,
      save_table=true,
      discrete_time=true}).

mc2b(N) when N>0, is_integer(N) ->
  mce:start
    (#mce_opts
     {program={dining,start,[N]},
      is_infinitely_fast=false,
      table={mce_table_bitHash,[10000000]},
      sends_are_sefs=true,
      well_behaved=true,
      partial_order=true,
      save_table=true,
      discrete_time=true}).

mc2c(N) when N>0, is_integer(N) ->
  mce:start
    (#mce_opts
     {program={dining,start,[N]},
      is_infinitely_fast=false,
      algorithm={mce_alg_safety_parallel,4},
      table={mce_table_bitHash,[10000000]},
      sends_are_sefs=true,
      well_behaved=true,
      partial_order=true,
      save_table=true,
      discrete_time=true}).

dot2(N) ->
  mc2(N),
  file:write_file
    ("hej.dot",
     mce_dot:from_table
     (mce_result:table(mce:result()),
      void,
      fun print_actions/1)).

dot_space(N) ->
  mce:start
    (#mce_opts
     {program={dining,start,[N]},
      is_infinitely_fast=false,
      table=mce_table_hashWithActions,
      sends_are_sefs=true,
      save_table=true,
      discrete_time=true}),
  file:write_file
    ("hej.dot",
     mce_dot:from_table
     (mce_result:table(mce:result()),
      void,
      fun print_actions/1)).

dot_space2(N) ->
  mce:start
    (#mce_opts
     {program={dining,start,[N]},
      is_infinitely_fast=false,
      table=mce_table_hashWithActions,
      sends_are_sefs=true,
      well_behaved=true,
      partial_order=true,
      save_table=true,
      discrete_time=true}),
  file:write_file
    ("hej.dot",
     mce_dot:from_table
     (mce_result:table(mce:result()),
      void,
      fun print_actions/1)).

dots(N) ->
  mc(N),
  file:write_file
    ("hej.dot",
     mce_dot:from_stack
     (mce_result:stack(mce:result()),
      void,
      fun print_actions/1)).

dots2(N) ->
  mc2(N),
  file:write_file
    ("hej.dot",
     mce_dot:from_stack
     (mce_result:stack(mce:result()),
      void,
      fun print_actions/1)).

print_states() ->
  Result = mce:result(),
  Table = mce_result:table(Result),
  {ok, States} = mce_behav_tableOps:states_to_list(Table),
  lists:foreach(fun (State) -> io:format("~p~n",[State]) end, States).

print_actions(Actions) ->
  SourceStr =
    case Actions of
      [Action|_] ->
	io_lib:format
	  ("~p: ",[simplify_pids(mce_erl_actions:get_source(Action))]);
      _ ->
	""
    end,
  ActionsStr =
    lists:foldl
      (fun (Action,Output) ->
	   ActionStr = print_action(Action),
	   if 
	     ActionStr=="" ->
	       Output;
	     Output=="" ->
	       io_lib:format("~s",[ActionStr]);
	     Output==[""] ->
	       io_lib:format("~s",[ActionStr]);
	     true ->
	       io_lib:format("~s,~s",[Output,ActionStr])
	   end
       end, "", Actions),
  "label=\""++SourceStr++ActionsStr++"\"".

print_action(Action) ->
  case mce_erl_actions:is_probe(Action) of
    true ->
      io_lib:format("~p",[mce_erl_actions:get_probe_label(Action)]);
    false ->
      case mce_erl_actions:is_send(Action) of
	true -> 
	  io_lib:format
	    ("sent ~p to ~p",
	     [simplify_pids(mce_erl_actions:get_send_msg(Action)),
	      simplify_pids(mce_erl_actions:get_send_pid(Action))]);
	false ->
	  case mce_erl_actions:is_api_call(Action) of
	    true ->
	      io_lib:format
		("~p(~p) -> ~p",
		 [mce_erl_actions:get_api_call_fun(Action),
		  mce_erl_actions:get_api_call_arguments(Action),
		  mce_erl_actions:get_api_call_result(Action)]);
	    false ->
	      case mce_erl_actions:is_timeout(Action) of
		true ->
		  case mce_erl_actions:get_timeout(Action) of
		    Tick={_,_,_} ->
		      io_lib:format("timeout ~p",[Tick]);
		    _ ->
		      io_lib:format("timeout",[])
		  end;
		false ->
		  case mce_erl_actions:get_name(Action) of
		    run -> "";
		    Name -> io_lib:format("~p",[Name])
		  end
	      end
	  end
      end
  end.

simplify_pids({pid,_,Pid}) ->
  Pid;
simplify_pids([First|Rest]) ->
  [simplify_pids(First)|simplify_pids(Rest)];
simplify_pids(Tuple) when is_tuple(Tuple) ->
  list_to_tuple(lists:map(fun simplify_pids/1,tuple_to_list(Tuple)));
simplify_pids(Other) -> 
  Other.

debug(N) when N>0, is_integer(N) ->
  mce:start
    (#mce_opts
     {program={dining,start,[N]},
      is_infinitely_fast=true,
      table=mce_table_hashWithActions,
      algorithm=mce_alg_debugger,
      sim_actions=true,
      sends_are_sefs=true,
      save_table=true,
      discrete_time=true}).

debug2(N) when N>0, is_integer(N) ->
  mce:start
    (#mce_opts
     {program={dining,start,[N]},
      is_infinitely_fast=true,
      table=mce_table_hashWithActions,
      algorithm=mce_alg_debugger,
      sim_actions=true,
      well_behaved=true,
      partial_order=true,
      sends_are_sefs=true,
      save_table=true,
      discrete_time=true}).