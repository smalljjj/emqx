%%--------------------------------------------------------------------
%% Copyright (c) 2020-2022 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------
-module(emqx_mgmt_api_stats).

-behaviour(minirest_api).

-include_lib("typerefl/include/types.hrl").

-import( hoconsc
       , [ mk/2
         , ref/1
         , ref/2
         , array/1]).

-export([ api_spec/0
        , paths/0
        , schema/1
        , fields/1
        ]).

-export([list/2]).

api_spec() ->
    emqx_dashboard_swagger:spec(?MODULE, #{check_schema => true}).

paths() ->
    ["/stats"].

schema("/stats") ->
    #{ 'operationId' => list
     , get =>
           #{ description => <<"EMQX stats">>
            , tags => [<<"stats">>]
            , parameters => [ref(aggregate)]
            , responses =>
                  #{ 200 => mk( hoconsc:union([ ref(?MODULE, base_data)
                                              , array(ref(?MODULE, aggergate_data))
                                              ])
                              , #{ desc => <<"List stats ok">> })
                   }
            }
     }.

fields(aggregate) ->
    [ { aggregate
      , mk( boolean()
          , #{ desc => <<"Calculation aggregate for all nodes">>
             , in => query
             , nullable => true
             , example => false})}
    ];
fields(base_data) ->
    [ { 'channels.count'
      , mk( integer(), #{ desc => <<"sessions.count">>
                        , example => 0})}
    , { 'channels.max'
      , mk( integer(), #{ desc => <<"session.max">>
                        , example => 0})}
    , { 'connections.count'
      , mk( integer(), #{ desc => <<"Number of current connections">>
                        , example => 0})}
    , { 'connections.max'
      , mk( integer(), #{ desc => <<"Historical maximum number of connections">>
                        , example => 0})}
    , { 'delayed.count'
      , mk( integer(), #{ desc => <<"Number of delayed messages">>
                        , example => 0})}
    , { 'delayed.max'
      , mk( integer(), #{ desc => <<"Historical maximum number of delayed messages">>
                        , example => 0})}
    , { 'live_connections.count'
      , mk( integer(), #{ desc => <<"Number of current live connections">>
                        , example => 0})}
    , { 'live_connections.max'
      , mk( integer(), #{ desc => <<"Historical maximum number of live connections">>
                        , example => 0})}
    , { 'retained.count'
      , mk( integer(), #{ desc => <<"Number of currently retained messages">>
                        , example => 0})}
    , { 'retained.max'
      , mk( integer(), #{ desc => <<"Historical maximum number of retained messages">>
                        , example => 0})}
    , { 'routes.count'
      , mk( integer(), #{ desc => <<"Number of current routes">>
                        , example => 0})}
    , { 'routes.max'
      , mk( integer(), #{ desc => <<"Historical maximum number of routes">>
                        , example => 0})}
    , { 'sessions.count'
      , mk( integer(), #{ desc => <<"Number of current sessions">>
                        , example => 0})}
    , { 'sessions.max'
      , mk( integer(), #{ desc => <<"Historical maximum number of sessions">>
                        , example => 0})}
    , { 'suboptions.count'
      , mk( integer(), #{ desc => <<"subscriptions.count">>
                        , example => 0})}
    , { 'suboptions.max'
      , mk( integer(), #{ desc => <<"subscriptions.max">>
                        , example => 0})}
    , { 'subscribers.count'
      , mk( integer(), #{ desc => <<"Number of current subscribers">>
                        , example => 0})}
    , { 'subscribers.max'
      , mk( integer(), #{ desc => <<"Historical maximum number of subscribers">>
                        , example => 0})}
    , { 'subscriptions.count'
      , mk( integer(), #{ desc => <<"Number of current subscriptions, including shared subscriptions">>
                        , example => 0})}
    , { 'subscriptions.max'
      , mk( integer(), #{ desc => <<"Historical maximum number of subscriptions">>
                        , example => 0})}
    , { 'subscriptions.shared.count'
      , mk( integer(), #{ desc => <<"Number of current shared subscriptions">>
                        , example => 0})}
    , { 'subscriptions.shared.max'
      , mk( integer(), #{ desc => <<"Historical maximum number of shared subscriptions">>
                        , example => 0})}
    , { 'topics.count'
      , mk( integer(), #{ desc => <<"Number of current topics">>
                        , example => 0})}
    , { 'topics.max'
      , mk( integer(), #{ desc => <<"Historical maximum number of topics">>
                        , example => 0})}
    ];
fields(aggergate_data) ->
    [ { node
      , mk( string(), #{ desc => <<"Node name">>
                       , example => <<"emqx@127.0.0.1">>})}
    ] ++ fields(base_data).


%%%==============================================================================================
%% api apply
list(get, #{query_string := Qs}) ->
    case maps:get(<<"aggregate">>, Qs, undefined) of
        true ->
            {200, emqx_mgmt:get_stats()};
        _ ->
            Data = [maps:from_list(emqx_mgmt:get_stats(Node) ++ [{node, Node}]) ||
                        Node <- mria_mnesia:running_nodes()],
            {200, Data}
    end.
