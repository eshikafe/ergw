%% Copyright 2017, Travelping GmbH <info@travelping.com>

%% This program is free software; you can redistribute it and/or
%% modify it under the terms of the GNU General Public License
%% as published by the Free Software Foundation; either version
%% 2 of the License, or (at your option) any later version.

-module(ggsn_proxy_SUITE).

-compile(export_all).

-include_lib("common_test/include/ct.hrl").
-include_lib("gtplib/include/gtp_packet.hrl").
-include("../include/ergw.hrl").
-include("../include/gtp_proxy_ds.hrl").
-include("ergw_test_lib.hrl").
-include("ergw_ggsn_test_lib.hrl").

-define(TIMEOUT, 2000).
-define(HUT, ggsn_gn_proxy).			%% Handler Under Test

%%%===================================================================
%%% API
%%%===================================================================

-define(TEST_CONFIG_MULTIPLE_PROXY_SOCKETS,
	[
	 {lager, [{colored, true},
		  {error_logger_redirect, true},
		  %% force lager into async logging, otherwise
		  %% the test will timeout randomly
		  {async_threshold, undefined},
		  {handlers, [{lager_console_backend, info}]}
		 ]},

	 {ergw, [{sockets,
		  [{irx, [{type, 'gtp-c'},
			  {ip,  ?TEST_GSN},
			  {reuseaddr, true}
			 ]},
		   {grx, [{type, 'gtp-u'},
			  {node, 'gtp-u-node@localhost'},
			  {name, 'grx'}
			 ]},
		   {'proxy-irx', [{type, 'gtp-c'},
				  {ip,  ?PROXY_GSN},
				  {reuseaddr, true}
				 ]},
		   {'proxy-grx', [{type, 'gtp-u'},
				  {node, 'gtp-u-proxy@vlx161-tpmd'},
				  {name, 'proxy-grx'}
				 ]},
		   {'remote-irx', [{type, 'gtp-c'},
				   {ip,  ?FINAL_GSN},
				   {reuseaddr, true}
				  ]},
		   {'remote-grx', [{type, 'gtp-u'},
				   {node, 'gtp-u-node@localhost'},
				   {name, 'remote-grx'}
				  ]}
		  ]},

		 {vrfs,
		  [{example, [{pools,  [{{10, 180, 0, 1}, {10, 180, 255, 254}, 32},
					{{16#8001, 0, 0, 0, 0, 0, 0, 0},
					 {16#8001, 0, 0, 16#FFFF, 0, 0, 0, 0}, 64}
				       ]},
			      {'MS-Primary-DNS-Server', {8,8,8,8}},
			      {'MS-Secondary-DNS-Server', {8,8,4,4}},
			      {'MS-Primary-NBNS-Server', {127,0,0,1}},
			      {'MS-Secondary-NBNS-Server', {127,0,0,1}}
			     ]}
		  ]},

		 {handlers,
		  %% proxy handler
		  [{gn, [{handler, ?HUT},
			 {sockets, [irx]},
			 {data_paths, [grx]},
			 {proxy_sockets, ['proxy-irx']},
			 {proxy_data_paths, ['proxy-grx']},
			 {ggsn, ?FINAL_GSN},
			 {contexts,
			  [{<<"ams">>,
			    [{proxy_sockets, ['proxy-irx']},
			     {proxy_data_paths, ['proxy-grx']}]}]}
			]},
		   %% remote GGSN handler
		   {gn, [{handler, ggsn_gn},
			 {sockets, ['remote-irx']},
			 {data_paths, ['remote-grx']},
			 {aaa, [{'Username',
				 [{default, ['IMSI', <<"@">>, 'APN']}]}]}
			]}
		  ]},

		 {apns,
		  [{?'APN-PROXY', [{vrf, example}]}
		  ]},

		 {proxy_map,
		  [{apn,  [{?'APN-EXAMPLE', ?'APN-PROXY'}]},
		   {imsi, [{?'IMSI', {?'PROXY-IMSI', ?'PROXY-MSISDN'}}
			  ]}
		  ]}			     ]},
	 {ergw_aaa, [{ergw_aaa_provider, {ergw_aaa_mock, [{secret, <<"MySecret">>}]}}]}
	]).

-define(TEST_CONFIG_SINGLE_PROXY_SOCKET,
	[
	 {lager, [{colored, true},
		  {error_logger_redirect, true},
		  %% force lager into async logging, otherwise
		  %% the test will timeout randomly
		  {async_threshold, undefined},
		  {handlers, [{lager_console_backend, info}]}
		 ]},

	 {ergw, [{sockets,
		  [{irx, [{type, 'gtp-c'},
			  {ip,  ?TEST_GSN},
			  {reuseaddr, true}
			 ]},
		   {grx, [{type, 'gtp-u'},
			  {node, 'gtp-u-node@localhost'},
			  {name, 'grx'}
			 ]},
		   {'remote-irx', [{type, 'gtp-c'},
				   {ip,  ?FINAL_GSN},
				   {reuseaddr, true}
				  ]},
		   {'remote-grx', [{type, 'gtp-u'},
				   {node, 'gtp-u-node@localhost'},
				   {name, 'remote-grx'}
				  ]}
		  ]},

		 {vrfs,
		  [{example, [{pools,  [{{10, 180, 0, 1}, {10, 180, 255, 254}, 32},
					{{16#8001, 0, 0, 0, 0, 0, 0, 0},
					 {16#8001, 0, 0, 16#FFFF, 0, 0, 0, 0}, 64}
				       ]},
			      {'MS-Primary-DNS-Server', {8,8,8,8}},
			      {'MS-Secondary-DNS-Server', {8,8,4,4}},
			      {'MS-Primary-NBNS-Server', {127,0,0,1}},
			      {'MS-Secondary-NBNS-Server', {127,0,0,1}}
			     ]}
		  ]},

		 {handlers,
		  %% proxy handler
		  [{gn, [{handler, ?HUT},
			 {sockets, [irx]},
			 {data_paths, [grx]},
			 {proxy_sockets, ['irx']},
			 {proxy_data_paths, ['grx']},
			 {ggsn, ?FINAL_GSN},
			 {contexts,
			  [{<<"ams">>,
			    [{proxy_sockets, ['irx']},
			     {proxy_data_paths, ['grx']}]}]}
			]},
		   %% remote GGSN handler
		   {gn, [{handler, ggsn_gn},
			 {sockets, ['remote-irx']},
			 {data_paths, ['remote-grx']},
			 {aaa, [{'Username',
				 [{default, ['IMSI', <<"@">>, 'APN']}]}]}
			]}
		  ]},

		 {apns,
		  [{?'APN-PROXY', [{vrf, example}]}
		  ]},

		 {proxy_map,
		  [{apn,  [{?'APN-EXAMPLE', ?'APN-PROXY'}]},
		   {imsi, [{?'IMSI', {?'PROXY-IMSI', ?'PROXY-MSISDN'}}
			  ]}
		  ]}			     ]},
	 {ergw_aaa, [{ergw_aaa_provider, {ergw_aaa_mock, [{secret, <<"MySecret">>}]}}]}
	]).

suite() ->
    [{timetrap,{seconds,30}}].

init_per_suite(Config0) ->
    [{handler_under_test, ?HUT} | Config0].

end_per_suite(_Config) ->
    ok.

init_per_group(single_proxy_interface, Config0) ->
    Config = lists:keystore(app_cfg, 1, Config0,
			    {app_cfg, ?TEST_CONFIG_SINGLE_PROXY_SOCKET}),
    lib_init_per_suite(Config);
init_per_group(_Group, Config0) ->
    Config = lists:keystore(app_cfg, 1, Config0,
			    {app_cfg, ?TEST_CONFIG_MULTIPLE_PROXY_SOCKETS}),
    lib_init_per_suite(Config).

end_per_group(_Group, Config) ->
    ok = lib_end_per_suite(Config),
    ok.

%% groups() ->
%%     [{single_proxy_interface, [], [path_restart]}].

%% all() ->
%%     [{group, single_proxy_interface}].

groups() ->
    [{single_proxy_interface, [], all_tests()},
     {multiple_proxy_interface, [], all_tests()}].

all() ->
    [{group, single_proxy_interface},
     {group, multiple_proxy_interface}].

all_tests() ->
    [invalid_gtp_pdu,
     create_pdp_context_request_missing_ie,
     path_restart, path_restart_recovery,
     simple_pdp_context_request,
     create_pdp_context_request_resend,
     delete_pdp_context_request_resend,
     update_pdp_context_request_ra_update,
     update_pdp_context_request_tei_update,
     ms_info_change_notification_request_with_tei,
     ms_info_change_notification_request_without_tei,
     ms_info_change_notification_request_invalid_imsi,
     proxy_context_selection,
     proxy_context_invalid_selection,
     invalid_teid,
     delete_pdp_context_requested,
     delete_pdp_context_requested_resend].

%%%===================================================================
%%% Tests
%%%===================================================================

init_per_testcase(path_restart, Config) ->
    ct:pal("Sockets: ~p", [gtp_socket_reg:all()]),
    meck_reset(Config),
    ok = meck:new(gtp_path, [passthrough, no_link]),
    Config;
init_per_testcase(TestCase, Config)
  when TestCase == delete_pdp_context_requested_resend ->
    ct:pal("Sockets: ~p", [gtp_socket_reg:all()]),
    ok = meck:expect(gtp_socket, send_request,
		     fun(GtpPort, From, RemoteIP, _T3, _N3,
			 #gtp{type = delete_pdp_context_request} = Msg, ReqId) ->
			     %% reduce timeout to 1 second and 2 resends
			     %% to speed up the test
			     meck:passthrough([GtpPort, From, RemoteIP,
					       1000, 2, Msg, ReqId]);
			(GtpPort, From, RemoteIP, T3, N3, Msg, ReqId) ->
			     meck:passthrough([GtpPort, From, RemoteIP,
					       T3, N3, Msg, ReqId])
		     end),
    meck_reset(Config),
    true = meck:validate(gtp_dp),
    Config;
init_per_testcase(_, Config) ->
    ct:pal("Sockets: ~p", [gtp_socket_reg:all()]),
    meck_reset(Config),
    Config.

end_per_testcase(path_restart, Config) ->
    meck:unload(gtp_path),
    Config;
end_per_testcase(TestCase, Config)
  when TestCase == delete_pdp_context_requested_resend ->
    ok = meck:delete(gtp_socket, send_request, 7),
    Config;
end_per_testcase(_, Config) ->
    Config.

%%--------------------------------------------------------------------
invalid_gtp_pdu() ->
    [{doc, "Test that an invalid PDU is silently ignored"
      " and that the GTP socket is not crashing"}].
invalid_gtp_pdu(Config) ->
    S = make_gtp_socket(Config),
    gen_udp:send(S, ?TEST_GSN, ?GTP1c_PORT, <<"TESTDATA">>),

    ?equal({error,timeout}, gen_udp:recv(S, 4096, ?TIMEOUT)),
    meck_validate(Config),
    ok.

%%--------------------------------------------------------------------
create_pdp_context_request_missing_ie() ->
    [{doc, "Check that Create Session Request IE validation works"}].
create_pdp_context_request_missing_ie(Config) ->
    S = make_gtp_socket(Config),

    create_pdp_context(missing_ie, S),

    meck_validate(Config),
    ok.

%%--------------------------------------------------------------------
path_restart() ->
    [{doc, "Check that Create PDP Context Request works and "
           "that a Path Restart terminates the session"}].
path_restart(Config) ->
    S = make_gtp_socket(Config),

    {GtpC, _, _} = create_pdp_context(S),

    %% simulate patch restart to kill the PDP context
    Echo = make_request(echo_request, simple,
			gtp_context_inc_seq(
			  gtp_context_inc_restart_counter(GtpC))),
    send_recv_pdu(S, Echo),

    ok = meck:wait(?HUT, terminate, '_', ?TIMEOUT),
    meck_validate(Config),
    ok.

%%--------------------------------------------------------------------
path_restart_recovery() ->
    [{doc, "Check that Create PDP Context Request works and "
           "that a Path Restart terminates the session"}].
path_restart_recovery(Config) ->
    S = make_gtp_socket(Config),

    {GtpC1, _, _} = create_pdp_context(S),

    %% create 2nd session with new restart_counter (simulate SGSN restart)
    {GtpC2, _, _} = create_pdp_context(S, gtp_context_inc_restart_counter(GtpC1)),

    delete_pdp_context(S, GtpC2),

    ok = meck:wait(?HUT, terminate, '_', ?TIMEOUT),
    meck_validate(Config),
    ok.

%%--------------------------------------------------------------------
simple_pdp_context_request() ->
    [{doc, "Check simple Create PDP Context, Delete PDP Context sequence"}].
simple_pdp_context_request(Config) ->
    S = make_gtp_socket(Config),

    {GtpC, _, _} = create_pdp_context(S),
    delete_pdp_context(S, GtpC),

    ok = meck:wait(?HUT, terminate, '_', ?TIMEOUT),
    meck_validate(Config),
    ok.

%%--------------------------------------------------------------------
create_pdp_context_request_resend() ->
    [{doc, "Check that a retransmission of a Create PDP Context Request works"}].
create_pdp_context_request_resend(Config) ->
    S = make_gtp_socket(Config),

    {GtpC, Msg, Response} = create_pdp_context(S),
    ?match(Response, send_recv_pdu(S, Msg)),

    delete_pdp_context(S, GtpC),

    ok = meck:wait(?HUT, terminate, '_', ?TIMEOUT),
    meck_validate(Config),
    ok.

%%--------------------------------------------------------------------
delete_pdp_context_request_resend() ->
    [{doc, "Check that a retransmission of a Delete PDP Context Request works"}].
delete_pdp_context_request_resend(Config) ->
    S = make_gtp_socket(Config),

    {GtpC, _, _} = create_pdp_context(S),
    {_, Msg, Response} = delete_pdp_context(S, GtpC),
    ?match(Response, send_recv_pdu(S, Msg)),

    ok = meck:wait(?HUT, terminate, '_', ?TIMEOUT),
    meck_validate(Config),
    ok.

%%--------------------------------------------------------------------
update_pdp_context_request_ra_update() ->
    [{doc, "Check Update PDP Context with Routing Area Update"}].
update_pdp_context_request_ra_update(Config) ->
    S = make_gtp_socket(Config),

    {GtpC1, _, _} = create_pdp_context(S),
    {GtpC2, _, _} = update_pdp_context(ra_update, S, GtpC1),
    delete_pdp_context(S, GtpC2),

    ok = meck:wait(?HUT, terminate, '_', ?TIMEOUT),
    meck_validate(Config),
    ok.

%%--------------------------------------------------------------------
update_pdp_context_request_tei_update() ->
    [{doc, "Check Update PDP Context with TEID update (e.g. SGSN change)"}].
update_pdp_context_request_tei_update(Config) ->
    S = make_gtp_socket(Config),

    {GtpC1, _, _} = create_pdp_context(S),
    {GtpC2, _, _} = update_pdp_context(tei_update, S, GtpC1),
    delete_pdp_context(S, GtpC2),

    ok = meck:wait(?HUT, terminate, '_', ?TIMEOUT),
    meck_validate(Config),
    ok.

%%--------------------------------------------------------------------
ms_info_change_notification_request_with_tei() ->
    [{doc, "Check Ms_Info_Change Notification request with TEID"}].
ms_info_change_notification_request_with_tei(Config) ->
    S = make_gtp_socket(Config),

    {GtpC1, _, _} = create_pdp_context(S),
    {GtpC2, _, _} = ms_info_change_notification(simple, S, GtpC1),
    delete_pdp_context(S, GtpC2),

    ok = meck:wait(?HUT, terminate, '_', ?TIMEOUT),
    meck_validate(Config),
    ok.

%%--------------------------------------------------------------------
ms_info_change_notification_request_without_tei() ->
    [{doc, "Check Ms_Info_Change Notification request without TEID "
           "include IMEI and IMSI instead"}].
ms_info_change_notification_request_without_tei(Config) ->
    S = make_gtp_socket(Config),

    {GtpC1, _, _} = create_pdp_context(S),
    {GtpC2, _, _} = ms_info_change_notification(without_tei, S, GtpC1),
    delete_pdp_context(S, GtpC2),

    ok = meck:wait(?HUT, terminate, '_', ?TIMEOUT),
    meck_validate(Config),
    ok.

%%--------------------------------------------------------------------
ms_info_change_notification_request_invalid_imsi() ->
    [{doc, "Check Ms_Info_Change Notification request without TEID "
           "include a invalid IMEI and IMSI instead"}].
ms_info_change_notification_request_invalid_imsi(Config) ->
    S = make_gtp_socket(Config),

    {GtpC1, _, _} = create_pdp_context(S),
    {GtpC2, _, _} = ms_info_change_notification(invalid_imsi, S, GtpC1),
    delete_pdp_context(S, GtpC2),

    ok = meck:wait(?HUT, terminate, '_', ?TIMEOUT),
    meck_validate(Config),
    ok.

%%--------------------------------------------------------------------
proxy_context_selection() ->
    [{doc, "Check that the proxy context selection works"}].
proxy_context_selection(Config) ->
    ok = meck:new(gtp_proxy_ds, [passthrough]),
    meck:expect(gtp_proxy_ds, map,
		fun(ProxyInfo) ->
			proxy_context_selection_map(ProxyInfo, <<"ams">>)
		end),

    S = make_gtp_socket(Config),

    {GtpC, _, _} = create_pdp_context(S),
    delete_pdp_context(S, GtpC),

    meck:unload(gtp_proxy_ds),

    ok = meck:wait(?HUT, terminate, '_', ?TIMEOUT),
    meck_validate(Config),
    ok.

%%--------------------------------------------------------------------
proxy_context_invalid_selection() ->
    [{doc, "Check that the proxy context selection works"}].
proxy_context_invalid_selection(Config) ->
    ok = meck:new(gtp_proxy_ds, [passthrough]),
    meck:expect(gtp_proxy_ds, map,
		fun(ProxyInfo) ->
			proxy_context_selection_map(ProxyInfo, <<"undefined">>)
		end),

    S = make_gtp_socket(Config),

    {GtpC, _, _} = create_pdp_context(S),
    delete_pdp_context(S, GtpC),

    meck:unload(gtp_proxy_ds),

    ok = meck:wait(?HUT, terminate, '_', ?TIMEOUT),
    meck_validate(Config),
    ok.

%%--------------------------------------------------------------------
invalid_teid() ->
    [{doc, "Check invalid TEID's for a number of request types"}].
invalid_teid(Config) ->
    S = make_gtp_socket(Config),

    {GtpC1, _, _} = create_pdp_context(S),
    {GtpC2, _, _} = delete_pdp_context(invalid_teid, S, GtpC1),
    {GtpC3, _, _} = update_pdp_context(invalid_teid, S, GtpC2),
    {GtpC4, _, _} = ms_info_change_notification(invalid_teid, S, GtpC3),
    delete_pdp_context(S, GtpC4),

    ok = meck:wait(?HUT, terminate, '_', ?TIMEOUT),
    meck_validate(Config),
    ok.

%%--------------------------------------------------------------------
delete_pdp_context_requested() ->
    [{doc, "Check GGSN initiated Delete PDP Context"}].
delete_pdp_context_requested(Config) ->
    S = make_gtp_socket(Config),

    {GtpC, _, _} = create_pdp_context(S),

    Context = gtp_context_reg:lookup(#gtp_port{name = 'remote-irx'},
				     {imsi, ?'PROXY-IMSI'}),
    true = is_pid(Context),

    Self = self(),
    spawn(fun() -> Self ! {req, gtp_context:delete_context(Context)} end),

    Request = recv_pdu(S, 5000),
    ?match(#gtp{type = delete_pdp_context_request}, Request),
    Response = make_response(Request, simple, GtpC),
    send_pdu(S, Response),

    receive
	{req, {ok, request_accepted}} ->
	    ok;
	{req, Other} ->
	    ct:fail(Other)
    after ?TIMEOUT ->
	    ct:fail(timeout)
    end,
    ok = meck:wait(?HUT, terminate, '_', ?TIMEOUT),
    meck_validate(Config),
    ok.

%%--------------------------------------------------------------------
delete_pdp_context_requested_resend() ->
    [{doc, "Check resend of GGSN initiated Delete PDP Context"}].
delete_pdp_context_requested_resend(Config) ->
    S = make_gtp_socket(Config),

    {_, _, _} = create_pdp_context(S),

    Context = gtp_context_reg:lookup(#gtp_port{name = 'remote-irx'},
				     {imsi, ?'PROXY-IMSI'}),
    true = is_pid(Context),

    Self = self(),
    spawn(fun() -> Self ! {req, gtp_context:delete_context(Context)} end),

    Request = recv_pdu(S, 5000),
    ?match(#gtp{type = delete_pdp_context_request}, Request),
    ?equal(Request, recv_pdu(S, 5000)),
    ?equal(Request, recv_pdu(S, 5000)),

    receive
	{req, {error, timeout}} ->
	    ok
    after ?TIMEOUT ->
	    ct:fail(timeout)
    end,
    meck_validate(Config),
    ok.

%%%===================================================================
%%% Internal functions
%%%===================================================================

proxy_context_selection_map(ProxyInfo, Context) ->
    case meck:passthrough([ProxyInfo]) of
	{ok, #proxy_info{} = P} ->
	    {ok, P#proxy_info{context = Context}};
	Other ->
	    Other
    end.
