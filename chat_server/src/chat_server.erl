%%%-------------------------------------------------------------------
%%% @author Piotr Anielski <pr.anielski@gmail.com>
%%% @copyright (C) 2015, Piotr Anielski
%%% @doc
%%% A simple chat server module
%%% @end
%%% Created : 16 Mar 2015 by Piotr Anielski <pr.anielski@gmail.com>
%%%-------------------------------------------------------------------
-module(chat_server).

-behaviour(gen_server).

%% API
-export([start_link/0, stop/0, join/1, say/2, leave/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {clients :: dict:dict()}).

%%%===================================================================
%%% API
%%%===================================================================
%% join(Name) ->



%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

stop() ->
    gen_server:call(?SERVER, stop).

join(Name) ->
    gen_server:call(?SERVER, {join, Name, self()}).

say(Name, Msg) ->
    gen_server:cast(?SERVER, {say, Name, Msg}).

leave(Name) ->
    gen_server:cast(?SERVER, {leave, Name}).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
init([]) ->
    {ok, #state{clients = dict:new()}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call({join, Name, Pid}, _From, State) ->
    {Reply, Clients} = handle_join(Name, Pid, State#state.clients),
    {reply, Reply, State#state{clients = Clients}};
handle_call(stop, _From, State) ->
    io:format("Stopping~n"),
    {stop, normal, ok, State};
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_cast({say, Name, Msg}, State) ->
    Message = {message, Name, Msg},
    %% TODO if message starts with '\', do sth
    broadcast_message(Message, State#state.clients),
    {noreply, State};
handle_cast({leave, Name}, State) ->
    Clients = dict:erase(Name, State#state.clients),
    Unpresence = {unpresence, Name},
    broadcast_message(Unpresence, Clients),
    {noreply, State#state{clients = Clients}};
handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

handle_join(Name, Pid, Clients) ->
    case dict:is_key(Name, Clients) of
        false ->

            io:format("~p joins~n", [Name]),

            Presence = {presence, Name},
            NewClients = dict:store(Name, Pid, Clients),
            broadcast_message(Presence, NewClients),
            {ok, NewClients};
        _ ->

            io:format("~p already taken ~n", [Name]),

            {{error, name_already_taken}, Clients}
    end.

broadcast_message(Msg, ClientsDict) ->

    io:format("broadcasting message from ~p: ~p~n", [Name, Msg]),

    [chat_client_handler:send_to_client(Pid, Msg)
     || {_ClientName, Pid} <- dict:to_list(ClientsDict)].
