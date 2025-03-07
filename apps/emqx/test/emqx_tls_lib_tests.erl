%%--------------------------------------------------------------------
%% Copyright (c) 2021-2022 EMQ Technologies Co., Ltd. All Rights Reserved.
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

-module(emqx_tls_lib_tests).

-include_lib("eunit/include/eunit.hrl").

%% one of the cipher suite from tlsv1.2 and tlsv1.3 each
-define(TLS_12_CIPHER, "ECDHE-ECDSA-AES256-GCM-SHA384").
-define(TLS_13_CIPHER, "TLS_AES_256_GCM_SHA384").

ensure_tls13_ciphers_added_test() ->
    Ciphers = emqx_tls_lib:integral_ciphers(['tlsv1.3'], [?TLS_12_CIPHER]),
    ?assert(lists:member(?TLS_12_CIPHER, Ciphers)),
    ?assert(lists:member(?TLS_13_CIPHER, Ciphers)).

legacy_cipher_suites_test() ->
    Ciphers = emqx_tls_lib:integral_ciphers(['tlsv1.2'], [?TLS_12_CIPHER]),
    ?assertEqual([?TLS_12_CIPHER], Ciphers).

use_default_ciphers_test() ->
    Ciphers = emqx_tls_lib:integral_ciphers(['tlsv1.3', 'tlsv1.2'], ""),
    ?assert(lists:member(?TLS_12_CIPHER, Ciphers)),
    ?assert(lists:member(?TLS_13_CIPHER, Ciphers)).

ciphers_format_test_() ->
    String = ?TLS_13_CIPHER ++ "," ++ ?TLS_12_CIPHER,
    Binary = bin(String),
    List = [?TLS_13_CIPHER, ?TLS_12_CIPHER],
    [ {"string", fun() -> test_cipher_format(String) end}
    , {"binary", fun() -> test_cipher_format(Binary) end}
    , {"string-list", fun() -> test_cipher_format(List) end}
    ].

test_cipher_format(Input) ->
    Ciphers = emqx_tls_lib:integral_ciphers(['tlsv1.3', 'tlsv1.2'], Input),
    ?assertEqual([?TLS_13_CIPHER, ?TLS_12_CIPHER], Ciphers).

tls_versions_test() ->
    ?assert(lists:member('tlsv1.3', emqx_tls_lib:default_versions())).

tls_version_unknown_test() ->
    ?assertEqual(emqx_tls_lib:default_versions(),
                 emqx_tls_lib:integral_versions([])),
    ?assertEqual(emqx_tls_lib:default_versions(),
                 emqx_tls_lib:integral_versions(<<>>)),
    ?assertEqual(emqx_tls_lib:default_versions(),
                 emqx_tls_lib:integral_versions("foo")),
    ?assertError(#{reason := no_available_tls_version},
                 emqx_tls_lib:integral_versions([foo])).

cipher_suites_no_duplication_test() ->
    AllCiphers = emqx_tls_lib:default_ciphers(),
    ?assertEqual(length(AllCiphers), length(lists:usort(AllCiphers))).

ssl_files_failure_test_() ->
    [{"undefined_is_undefined",
      fun() ->
              ?assertEqual({ok, undefined},
                           emqx_tls_lib:ensure_ssl_files("dir", undefined)) end},
     {"no_op_if_disabled",
      fun() ->
              Disabled = #{<<"enable">> => false, foo => bar},
              ?assertEqual({ok, Disabled},
                           emqx_tls_lib:ensure_ssl_files("dir", Disabled)) end},
     {"enoent_key_file",
      fun() ->
              NonExistingFile = filename:join("/tmp", integer_to_list(erlang:system_time(microsecond))),
              ?assertMatch({error, #{file_read := enoent, pem_check := invalid_pem}},
                           emqx_tls_lib:ensure_ssl_files("/tmp", #{<<"keyfile">> => NonExistingFile}))
      end},
     {"bad_pem_string",
      fun() ->
              %% not valid unicode
              ?assertMatch({error, #{reason := invalid_file_path_or_pem_string, which_option := <<"keyfile">>}},
                           emqx_tls_lib:ensure_ssl_files("/tmp", #{<<"keyfile">> => <<255, 255>>})),
              %% not printable
              ?assertMatch({error, #{reason := invalid_file_path_or_pem_string}},
                           emqx_tls_lib:ensure_ssl_files("/tmp", #{<<"keyfile">> => <<33, 22>>})),
              TmpFile = filename:join("/tmp", integer_to_list(erlang:system_time(microsecond))),
              try
                  ok = file:write_file(TmpFile, <<"not a valid pem">>),
                  ?assertMatch({error, #{file_read := not_pem}},
                               emqx_tls_lib:ensure_ssl_files("/tmp", #{<<"cacertfile">> => bin(TmpFile)}))
              after
                  file:delete(TmpFile)
              end
      end}
    ].

ssl_files_save_delete_test() ->
    SSL0 = #{<<"keyfile">> => bin(test_key())},
    Dir = filename:join(["/tmp", "ssl-test-dir"]),
    {ok, SSL} = emqx_tls_lib:ensure_ssl_files(Dir, SSL0),
    File = maps:get(<<"keyfile">>, SSL),
    ?assertMatch(<<"/tmp/ssl-test-dir/key-", _:16/binary>>, File),
    ?assertEqual({ok, bin(test_key())}, file:read_file(File)),
    %% no old file to delete
    ok = emqx_tls_lib:delete_ssl_files(Dir, SSL, undefined),
    ?assertEqual({ok, bin(test_key())}, file:read_file(File)),
    %% old and new identical, no delete
    ok = emqx_tls_lib:delete_ssl_files(Dir, SSL, SSL),
    ?assertEqual({ok, bin(test_key())}, file:read_file(File)),
    %% new is gone, delete old
    ok = emqx_tls_lib:delete_ssl_files(Dir, undefined, SSL),
    ?assertEqual({error, enoent}, file:read_file(File)),
    %% test idempotence
    ok = emqx_tls_lib:delete_ssl_files(Dir, undefined, SSL),
    ok.

ssl_file_replace_test() ->
    SSL0 = #{<<"keyfile">> => bin(test_key())},
    SSL1 = #{<<"keyfile">> => bin(test_key2())},
    Dir = filename:join(["/tmp", "ssl-test-dir2"]),
    {ok, SSL2} = emqx_tls_lib:ensure_ssl_files(Dir, SSL0),
    {ok, SSL3} = emqx_tls_lib:ensure_ssl_files(Dir, SSL1),
    File1 = maps:get(<<"keyfile">>, SSL2),
    File2 = maps:get(<<"keyfile">>, SSL3),
    ?assert(filelib:is_regular(File1)),
    ?assert(filelib:is_regular(File2)),
    %% delete old file (File1, in SSL2)
    ok = emqx_tls_lib:delete_ssl_files(Dir, SSL3, SSL2),
    ?assertNot(filelib:is_regular(File1)),
    ?assert(filelib:is_regular(File2)),
    ok.

bin(X) -> iolist_to_binary(X).

test_key() ->
"""
-----BEGIN EC PRIVATE KEY-----
MHQCAQEEICKTbbathzvD8zvgjL7qRHhW4alS0+j0Loo7WeYX9AxaoAcGBSuBBAAK
oUQDQgAEJBdF7MIdam5T4YF3JkEyaPKdG64TVWCHwr/plC0QzNVJ67efXwxlVGTo
ju0VBj6tOX1y6C0U+85VOM0UU5xqvw==
-----END EC PRIVATE KEY-----
""".

test_key2() ->
"""
-----BEGIN EC PRIVATE KEY-----
MHQCAQEEID9UlIyAlLFw0irkRHX29N+ZGivGtDjlVJvATY3B0TTmoAcGBSuBBAAK
oUQDQgAEUwiarudRNAT25X11js8gE9G+q0GdsT53QJQjRtBO+rTwuCW1vhLzN0Ve
AbToUD4JmV9m/XwcSVH06ZaWqNuC5w==
-----END EC PRIVATE KEY-----
""".
