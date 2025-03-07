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

-module(emqx_rewrite_SUITE).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("emqx/include/emqx_mqtt.hrl").
-include_lib("eunit/include/eunit.hrl").

-define(REWRITE, <<"""
rewrite: [
    {
      action : publish
      source_topic : \"x/#\"
      re : \"^x/y/(.+)$\"
      dest_topic : \"z/y/$1\"
    },
    {
      action : subscribe
      source_topic : \"y/+/z/#\"
      re : \"^y/(.+)/z/(.+)$\"
      dest_topic : \"y/z/$2\"
    },
    {
      action : all
      source_topic : \"all/+/x/#\"
      re : \"^all/(.+)/x/(.+)$\"
      dest_topic : \"all/x/$2\"
    }
]""">>).

all() -> emqx_common_test_helpers:all(?MODULE).

init_per_suite(Config) ->
    emqx_common_test_helpers:boot_modules(all),
    emqx_common_test_helpers:start_apps([emqx_conf, emqx_modules]),
    Config.

end_per_suite(_Config) ->
    emqx_common_test_helpers:stop_apps([emqx_conf, emqx_modules]).

t_subscribe_rewrite(_Config) ->
    {ok, Conn} = init(),
    SubOrigTopics = [<<"y/a/z/b">>, <<"y/def">>],
    SubDestTopics = [<<"y/z/b">>, <<"y/def">>],
    {ok, _Props1, _} = emqtt:subscribe(Conn, [{Topic, ?QOS_1} || Topic <- SubOrigTopics]),
    timer:sleep(150),
    Subscriptions = emqx_broker:subscriptions(<<"rewrite_client">>),
    ?assertEqual(SubDestTopics, [Topic || {Topic, _SubOpts} <- Subscriptions]),
    RecvTopics = [begin
                       ok = emqtt:publish(Conn, Topic, <<"payload">>),
                       {ok, #{topic := RecvTopic}} = receive_publish(100),
                       RecvTopic
                   end || Topic <- SubDestTopics],
    ?assertEqual(SubDestTopics, RecvTopics),
    {ok, _, _} = emqtt:unsubscribe(Conn, SubOrigTopics),
    timer:sleep(100),
    ?assertEqual([], emqx_broker:subscriptions(<<"rewrite_client">>)),

    terminate(Conn).

t_publish_rewrite(_Config) ->
    {ok, Conn} = init(),
    PubOrigTopics = [<<"x/y/2">>, <<"x/1/2">>],
    PubDestTopics = [<<"z/y/2">>, <<"x/1/2">>],
    {ok, _Props2, _} = emqtt:subscribe(Conn, [{Topic, ?QOS_1} || Topic <- PubDestTopics]),
    RecvTopics = [begin
                       ok = emqtt:publish(Conn, Topic, <<"payload">>),
                       {ok, #{topic := RecvTopic}} = receive_publish(100),
                       RecvTopic
                   end || Topic <- PubOrigTopics],
    ?assertEqual(PubDestTopics, RecvTopics),
    {ok, _, _} = emqtt:unsubscribe(Conn, PubDestTopics),
    terminate(Conn).

t_rewrite_rule(_Config) ->
    {PubRules, SubRules, []} = emqx_rewrite:compile(emqx:get_config([rewrite])),
    ?assertEqual(<<"z/y/2">>, emqx_rewrite:match_and_rewrite(<<"x/y/2">>, PubRules)),
    ?assertEqual(<<"x/1/2">>, emqx_rewrite:match_and_rewrite(<<"x/1/2">>, PubRules)),
    ?assertEqual(<<"y/z/b">>, emqx_rewrite:match_and_rewrite(<<"y/a/z/b">>, SubRules)),
    ?assertEqual(<<"y/def">>, emqx_rewrite:match_and_rewrite(<<"y/def">>, SubRules)).

t_rewrite_re_error(_Config) ->
    Rules = [#{
        action => subscribe,
        source_topic => "y/+/z/#",
        re => "{^y/(.+)/z/(.+)$*",
        dest_topic => "\"y/z/$2"
    }],
    Error = {
        "y/+/z/#",
        "{^y/(.+)/z/(.+)$*",
        "\"y/z/$2",
        {"nothing to repeat",16}
    },
    ?assertEqual({[], [], [Error]}, emqx_rewrite:compile(Rules)),
    ok.

t_list(_Config) ->
    ok = emqx_common_test_helpers:load_config(emqx_modules_schema, ?REWRITE),
    Expect = [
        #{<<"action">> => <<"publish">>,
            <<"dest_topic">> => <<"z/y/$1">>,
            <<"re">> => <<"^x/y/(.+)$">>,
            <<"source_topic">> => <<"x/#">>},
        #{<<"action">> => <<"subscribe">>,
            <<"dest_topic">> => <<"y/z/$2">>,
            <<"re">> => <<"^y/(.+)/z/(.+)$">>,
            <<"source_topic">> => <<"y/+/z/#">>},
        #{<<"action">> => <<"all">>,
            <<"dest_topic">> => <<"all/x/$2">>,
            <<"re">> => <<"^all/(.+)/x/(.+)$">>,
            <<"source_topic">> => <<"all/+/x/#">>}],
    ?assertEqual(Expect, emqx_rewrite:list()),
    ok.

t_update(_Config) ->
    ok = emqx_common_test_helpers:load_config(emqx_modules_schema, ?REWRITE),
    Init = emqx_rewrite:list(),
    Rules = [#{
        <<"source_topic">> => <<"test/#">>,
        <<"re">> => <<"test/*">>,
        <<"dest_topic">> => <<"test1/$2">>,
        <<"action">> => <<"publish">>
    }],
    ok = emqx_rewrite:update(Rules),
    ?assertEqual(Rules, emqx_rewrite:list()),
    ok = emqx_rewrite:update(Init),
    ok.

t_update_disable(_Config) ->
    ok = emqx_common_test_helpers:load_config(emqx_modules_schema, ?REWRITE),
    ?assertEqual(ok, emqx_rewrite:update([])),
    timer:sleep(150),

    Subs = emqx_hooks:lookup('client.subscribe'),
    UnSubs = emqx_hooks:lookup('client.unsubscribe'),
    MessagePub = emqx_hooks:lookup('message.publish'),
    Filter = fun({_, {Mod, _, _}, _, _}) -> Mod =:= emqx_rewrite end,

    ?assertEqual([], lists:filter(Filter, Subs)),
    ?assertEqual([], lists:filter(Filter, UnSubs)),
    ?assertEqual([], lists:filter(Filter, MessagePub)),
    ok.

t_update_re_failed(_Config) ->
    ok = emqx_common_test_helpers:load_config(emqx_modules_schema, ?REWRITE),
    Rules = [#{
        <<"source_topic">> => <<"test/#">>,
        <<"re">> => <<"*^test/*">>,
        <<"dest_topic">> => <<"test1/$2">>,
        <<"action">> => <<"publish">>
    }],
    Error = {badmatch,
        {error,
            {emqx_modules_schema,
                [{validation_error,
                    #{path => "rewrite.1.re",
                      reason => {<<"*^test/*">>,{"nothing to repeat",0}},
                      value => <<"*^test/*">>}}]}}},
    ?assertError(Error, emqx_rewrite:update(Rules)),
    ok.

%%--------------------------------------------------------------------
%% Internal functions
%%--------------------------------------------------------------------

receive_publish(Timeout) ->
    receive
        {publish, Publish} -> {ok, Publish}
    after
        Timeout -> {error, timeout}
    end.

init() ->
    ok = emqx_common_test_helpers:load_config(emqx_modules_schema, ?REWRITE),
    ok = emqx_rewrite:enable(),
    {ok, C} = emqtt:start_link([{clientid, <<"rewrite_client">>}]),
    {ok, _} = emqtt:connect(C),
    {ok, C}.

terminate(Conn) ->
    ok = emqtt:disconnect(Conn),
    ok = emqx_rewrite:disable().
