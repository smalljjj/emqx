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

-module(emqx_topic_metrics_api).

-behaviour(minirest_api).

-include_lib("typerefl/include/types.hrl").
-include("emqx_modules.hrl").

-import( hoconsc
       , [ mk/2
         , ref/1
         , ref/2
         , array/1
         , map/2]).

-export([ topic_metrics/2
        , operate_topic_metrics/2
        ]).

-export([ cluster_accumulation_metrics/0
        , cluster_accumulation_metrics/1]).

-export([ api_spec/0
        , paths/0
        , schema/1
        , fields/1
        ]).

-define(ERROR_TOPIC, 'ERROR_TOPIC').
-define(EXCEED_LIMIT, 'EXCEED_LIMIT').
-define(BAD_TOPIC, 'BAD_TOPIC').
-define(BAD_RPC, 'BAD_RPC').
-define(BAD_REQUEST, 'BAD_REQUEST').

api_spec() ->
    emqx_dashboard_swagger:spec(?MODULE, #{check_schema => true}).

paths() ->
    [ "/mqtt/topic_metrics"
    , "/mqtt/topic_metrics/:topic"
    ].


schema("/mqtt/topic_metrics") ->
    #{ 'operationId' => topic_metrics
     , get =>
           #{ description => <<"List topic metrics">>
            , tags => ?API_TAG_MQTT
            , responses  =>
                  #{200  => mk(array(hoconsc:ref(topic_metrics)), #{ desc => <<"List all topic metrics">>})}
            }
     , put =>
           #{ description => <<"Reset topic metrics by topic name. Or reset all Topic Metrics">>
            , tags => ?API_TAG_MQTT
            , 'requestBody' => emqx_dashboard_swagger:schema_with_examples(
                                 ref(reset),
                                 reset_examples())
            , responses =>
                  #{ 204 => <<"Reset topic metrics successfully">>
                   , 404 => emqx_dashboard_swagger:error_codes([?ERROR_TOPIC], <<"Topic not found">>)
                   }
            }
     , post =>
           #{ description => <<"Create topic metrics">>
            , tags => ?API_TAG_MQTT
            , 'requestBody' => [topic(body)]
            , responses =>
                  #{ 204 => <<"Create topic metrics success">>
                   , 409 => emqx_dashboard_swagger:error_codes([?EXCEED_LIMIT], <<"Topic metrics exceeded max limit 512">>)
                   , 400 => emqx_dashboard_swagger:error_codes([?BAD_REQUEST, ?BAD_TOPIC], <<"Topic metrics already existed or bad topic">>)
                   }
            }
     };
schema("/mqtt/topic_metrics/:topic") ->
    #{ 'operationId' =>  operate_topic_metrics
     , get =>
           #{ description => <<"Get topic metrics">>
            , tags => ?API_TAG_MQTT
            , parameters => [topic(path)]
            , responses =>
                  #{ 200 => mk(ref(topic_metrics), #{ desc => <<"Topic metrics">> })
                   , 404 => emqx_dashboard_swagger:error_codes([?ERROR_TOPIC], <<"Topic not found">>)
                   }
            }
     , delete =>
           #{ description => <<"Remove the topic metrics">>
            , tags => ?API_TAG_MQTT
            , parameters => [topic(path)]
            , responses =>
                  #{ 204 => <<"Removed topic metrics successfully">>,
                     404 => emqx_dashboard_swagger:error_codes([?ERROR_TOPIC], <<"Topic not found">>)
                   }
            }
     }.

fields(reset) ->
    [ {topic
      , mk( binary()
          , #{ desc => <<"Topic Name. If this parameter is not present, all created topic metrics will be reset">>
             , example => <<"testtopic/1">>
             , nullable => true})}
    , {action
      , mk( string()
          , #{ desc => <<"Action Name. Only as a \"reset\"">>
             , enum => [reset]
             , nullable => false
             , example => <<"reset">>})}
    ];

fields(topic_metrics) ->
    [ { topic
      , mk( binary()
          , #{ desc => <<"Topic Name">>
             , example => <<"testtopic/1">>
             , nullable => false})},
      { create_time
      , mk( emqx_datetime:epoch_second()
          , #{ desc => <<"Topic Metrics created date time, in rfc3339">>
             , nullable => false
             , example => <<"2022-01-14T21:48:47+08:00">>})},
      { reset_time
      , mk( emqx_datetime:epoch_second()
          , #{ desc => <<"Topic Metrics reset date time, in rfc3339. Nullable if never reset">>
             , nullable => true
             , example => <<"2022-01-14T21:48:47+08:00">>})},
      { metrics
      , mk( ref(metrics)
          , #{ desc => <<"Topic Metrics fields">>
             , nullable => false})
      }
    ];

fields(metrics) ->
    [ {'messages.dropped.count', mk(integer(),
        #{ desc => <<"Message dropped count">>
         , example => 0
         })}
    , {'messages.dropped.rate', mk(number(),
        #{ desc => <<"Message dropped rate in 5s">>
         , example => 0
         })}
    , {'messages.in.count', mk(integer(),
        #{ desc => <<"Message received count">>
         , example => 0
         })}
    , {'messages.in.rate', mk(number(),
        #{ desc => <<"Message received rate in 5s">>
         , example => 0
         })}
    , {'messages.out.count', mk(integer(),
        #{ desc => <<"Message sent count">>
         , example => 0
         })}
    , {'messages.out.rate', mk(number(),
        #{ desc => <<"Message sent rate in 5s">>
         , example => 0
         })}
    , {'messages.qos0.in.count', mk(integer(),
        #{ desc => <<"Message with QoS 0 received count">>
         , example => 0
         })}
    , {'messages.qos0.in.rate', mk(number(),
        #{ desc => <<"Message with QoS 0 received rate in 5s">>
         , example => 0
         })}
    , {'messages.qos0.out.count', mk(integer(),
        #{ desc => <<"Message with QoS 0 sent count">>
         , example => 0
         })}
    , {'messages.qos0.out.rate', mk(number(),
        #{ desc => <<"Message with QoS 0 sent rate in 5s">>
         , example => 0
         })}
    , {'messages.qos1.in.count', mk(integer(),
        #{ desc => <<"Message with QoS 1 received count">>
         , example => 0
         })}
    , {'messages.qos1.in.rate', mk(number(),
        #{ desc => <<"Message with QoS 1 received rate in 5s">>
         , example => 0
         })}
    , {'messages.qos1.out.count', mk(integer(),
        #{ desc => <<"Message with QoS 1 sent count">>
         , example => 0
         })}
    , {'messages.qos1.out.rate', mk(number(),
        #{ desc => <<"Message with QoS 1 sent rate in 5s">>
         , example => 0
         })}
    , {'messages.qos2.in.count', mk(integer(),
        #{ desc => <<"Message with QoS 2 sent count">>
         , example => 0
         })}
    , {'messages.qos2.in.rate', mk(number(),
        #{ desc => <<"Message with QoS 2 received rate in 5s">>
         , example => 0
         })}
    , {'messages.qos2.out.count', mk(integer(),
        #{ desc => <<"Message with QoS 2 sent count">>
         , example => 0
         })}
    , {'messages.qos2.out.rate', mk(number(),
        #{ desc => <<"Message with QoS 2 sent rate in 5s">>
         , example => 0
         })}
    ].

topic(In) ->
    case In of
        body ->
            Desc = <<"Raw topic string">>,
            Example = "testtopic/1";
        path ->
            Desc = <<"Notice: Topic string in url path must be encoded">>,
            Example = "testtopic%2F1"
    end,
    { topic
    , mk( binary(),
          #{ desc => Desc
           , required => true
           , in => In
           , example => Example
           })
    }.

reset_examples() ->
    #{ reset_specific_one_topic_metrics =>
           #{ summary => <<"reset_specific_one_topic_metrics">>
            , value =>
                  #{ topic  => "testtopic/1"
                   , action => "reset"
                   }
            }
     , reset_all_topic_metrics =>
           #{ summary => <<"reset_all_topic_metrics">>
            , value =>
                  #{ action => "reset"
                   }
            }
     }.

%%--------------------------------------------------------------------
%% HTTP Callbacks
%%--------------------------------------------------------------------

topic_metrics(get, _) ->
    get_cluster_response([]);

topic_metrics(put, #{body := #{<<"topic">> := Topic, <<"action">> := <<"reset">>}}) ->
    case reset(Topic) of
        ok ->
            get_cluster_response([Topic]);
        {error, Reason} ->
            reason2httpresp(Reason)
    end;
topic_metrics(put, #{body := #{<<"action">> := <<"reset">>}}) ->
    reset(),
    get_cluster_response([]);

topic_metrics(post, #{body := #{<<"topic">> := <<>>}}) ->
    {400, 'BAD_REQUEST', <<"Topic can not be empty">>};
topic_metrics(post, #{body := #{<<"topic">> := Topic}}) ->
    case emqx_modules_conf:add_topic_metrics(Topic) of
        {ok, Topic} ->
            get_cluster_response([Topic]);
        {error, Reason} ->
            reason2httpresp(Reason)
    end.

operate_topic_metrics(get, #{bindings := #{topic := Topic0}}) ->
    get_cluster_response([emqx_http_lib:uri_decode(Topic0)]);

operate_topic_metrics(delete, #{bindings := #{topic := Topic0}}) ->
    case emqx_modules_conf:remove_topic_metrics(emqx_http_lib:uri_decode(Topic0)) of
        ok -> {204};
        {error, Reason} -> reason2httpresp(Reason)
    end.

%%--------------------------------------------------------------------
%% Internal funcs
%%--------------------------------------------------------------------

cluster_accumulation_metrics() ->
    Nodes = mria_mnesia:running_nodes(),
    case emqx_topic_metrics_proto_v1:metrics(Nodes) of
        {SuccResList, []} ->
            {ok, accumulate_nodes_metrics(SuccResList)};
        {_, FailedNodes} ->
            {error, {badrpc, FailedNodes}}
    end.

cluster_accumulation_metrics(Topic) ->
    Nodes = mria_mnesia:running_nodes(),
    case emqx_topic_metrics_proto_v1:metrics(Nodes, Topic) of
        {SuccResList, []} ->
            case lists:filter(fun({error, _}) -> false; (_) -> true
                              end, SuccResList) of
                [] ->
                    {error, topic_not_found};
                TopicMetrics ->
                    NTopicMetrics = [ [T] || T <- TopicMetrics],
                    [AccMetrics] = accumulate_nodes_metrics(NTopicMetrics),
                    {ok, AccMetrics}
            end;
        {_, FailedNodes} ->
            {error, {badrpc, FailedNodes}}
    end.

accumulate_nodes_metrics(NodesTopicMetrics) ->
    AccMap = lists:foldl(fun(TopicMetrics, ExAcc) ->
        MetricsMap = lists:foldl(
                       fun(#{topic := Topic,
                             metrics := Metrics,
                             create_time := CreateTime}, Acc) ->
                               Acc#{Topic => {Metrics, CreateTime}}
                       end, #{}, TopicMetrics),
        accumulate_metrics(MetricsMap, ExAcc)
    end, #{}, NodesTopicMetrics),
    maps:fold(fun(Topic, {Metrics, CreateTime1}, Acc1) ->
        [#{topic => Topic,
           metrics => Metrics,
           create_time => CreateTime1} | Acc1]
    end, [], AccMap).

%% @doc TopicMetricsIn :: #{<<"topic">> := {Metrics, CreateTime}}
accumulate_metrics(TopicMetricsIn, TopicMetricsAcc) ->
    Topics = maps:keys(TopicMetricsIn),
    lists:foldl(fun(Topic, Acc) ->
        {Metrics, CreateTime} = maps:get(Topic, TopicMetricsIn),
        NMetrics = do_accumulation_metrics(
                     Metrics,
                     maps:get(Topic, TopicMetricsAcc, undefined)
                    ),
        maps:put(Topic, {NMetrics, CreateTime}, Acc)
    end, #{}, Topics).

%% @doc MetricsIn :: #{'messages.dropped.rate' :: integer(), ...}
do_accumulation_metrics(MetricsIn, undefined) -> MetricsIn;
do_accumulation_metrics(MetricsIn, {MetricsAcc, _}) ->
    Keys = maps:keys(MetricsIn),
    lists:foldl(fun(Key, Acc) ->
        InVal = maps:get(Key, MetricsIn),
        NVal = InVal + maps:get(Key, MetricsAcc, 0),
        maps:put(Key, NVal, Acc)
    end, #{}, Keys).

reset() ->
    Nodes = mria_mnesia:running_nodes(),
    _ = emqx_topic_metrics_proto_v1:reset(Nodes),
    ok.

reset(Topic) ->
    Nodes = mria_mnesia:running_nodes(),
    case emqx_topic_metrics_proto_v1:reset(Nodes, Topic) of
        {SuccResList, []} ->
            case lists:filter(fun({error, _}) -> true; (_) -> false
                              end, SuccResList) of
                [{error, Reason} | _] ->
                    {error, Reason};
                [] ->
                    ok
            end
    end.

%%--------------------------------------------------------------------
%% utils

reason2httpresp(quota_exceeded) ->
    Msg = list_to_binary(
            io_lib:format("Max topic metrics count is ~p",
                          [emqx_topic_metrics:max_limit()])),
    {409, #{code => ?EXCEED_LIMIT, message => Msg}};
reason2httpresp(bad_topic) ->
    Msg = <<"Bad Topic, topic cannot have wildcard">>,
    {400, #{code => ?BAD_TOPIC, message => Msg}};
reason2httpresp({quota_exceeded, bad_topic}) ->
    Msg = list_to_binary(
            io_lib:format(
              "Max topic metrics count is ~p, and topic cannot have wildcard",
              [emqx_topic_metrics:max_limit()])),
    {400, #{code => ?BAD_REQUEST, message => Msg}};
reason2httpresp(already_existed) ->
    Msg = <<"Topic already registered">>,
    {400, #{code => ?BAD_TOPIC, message => Msg}};
reason2httpresp(topic_not_found) ->
    Msg = <<"Topic not found">>,
    {404, #{code => ?ERROR_TOPIC, message => Msg}};
reason2httpresp(not_found) ->
    Msg = <<"Topic not found">>,
    {404, #{code => ?ERROR_TOPIC, message => Msg}}.

get_cluster_response(Args) ->
    case erlang:apply(?MODULE, cluster_accumulation_metrics, Args) of
        {error, {badrpc, RPCReason}} ->
            {500, RPCReason};
        {error, Reason} when is_atom(Reason) ->
            reason2httpresp(Reason);
        {ok, Metrics} ->
            {200, Metrics}
    end.
