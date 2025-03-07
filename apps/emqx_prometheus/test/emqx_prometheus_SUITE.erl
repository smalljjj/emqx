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

-module(emqx_prometheus_SUITE).

-include_lib("stdlib/include/assert.hrl").

-compile(nowarn_export_all).
-compile(export_all).

all() -> emqx_common_test_helpers:all(?MODULE).

t_start_stop(_) ->
    ?assertMatch(ok, emqx_prometheus:start()),
    ?assertMatch(ok, emqx_prometheus:stop()),
    ?assertMatch(ok, emqx_prometheus:restart()).
