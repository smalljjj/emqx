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

-module(emqx_config_SUITE).

-compile(export_all).
-compile(nowarn_export_all).
-include_lib("eunit/include/eunit.hrl").

all() -> emqx_common_test_helpers:all(?MODULE).

init_per_suite(Config) ->
    emqx_common_test_helpers:boot_modules(all),
    emqx_common_test_helpers:start_apps([]),
    Config.

end_per_suite(_Config) ->
    emqx_common_test_helpers:stop_apps([]).

t_fill_default_values(_) ->
    Conf = #{
      <<"broker">> => #{
        <<"perf">> => #{},
        <<"route_batch_clean">> => false}
    },
    WithDefaults = emqx_config:fill_defaults(Conf),
    ?assertMatch(#{<<"broker">> :=
      #{<<"enable_session_registry">> := true,
        <<"perf">> :=
            #{<<"route_lock_type">> := key,
              <<"trie_compaction">> := true},
        <<"route_batch_clean">> := false,
        <<"session_locking_strategy">> := quorum,
        <<"shared_dispatch_ack_enabled">> := false,
        <<"shared_subscription_strategy">> := round_robin,
        <<"sys_heartbeat_interval">> := <<"30s">>,
        <<"sys_msg_interval">> := <<"1m">>}}, WithDefaults),
    %% ensure JSON compatible
    _ = emqx_json:encode(WithDefaults),
    ok.
