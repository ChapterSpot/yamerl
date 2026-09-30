-module(flow_collection_anchors).

-include_lib("eunit/include/eunit.hrl").
-include("yamerl_nodes.hrl").

setup() ->
    application:start(yamerl).

proplist_test_() ->
    {setup,
      fun setup/0,
      [{Name, ?_assertEqual(
          [[{"a", simple(Expected, proplist)},
            {"b", simple(Expected, proplist)}]],
          yamerl_constr:string(Yaml, [{detailed_constr, false}]))}
        || {Name, Yaml, Expected} <- fixtures()]
    }.

map_test_() ->
    {setup,
      fun setup/0,
      [{Name, ?_assertEqual(
          [#{<<"a">> => simple(Expected, map),
             <<"b">> => simple(Expected, map)}],
          yamerl_constr:string(Yaml, [{detailed_constr, false},
            {map_node_format, map}, {str_node_as_binary, true}]))}
        || {Name, Yaml, Expected} <- fixtures()]
    }.

detailed_test_() ->
    {setup,
      fun setup/0,
      [{Name, ?_test(assert_detailed(Yaml, Expected))}
        || {Name, Yaml, Expected} <- fixtures()]
    }.

flow_map_key_test_() ->
    Yaml = "a: {&a x: base}\nb: *a\n",
    {setup,
      fun setup/0,
      [
        ?_assertEqual([[{"a", [{"x", "base"}]}, {"b", "x"}]],
          yamerl_constr:string(Yaml, [{detailed_constr, false}])),
        ?_assertEqual([#{<<"a">> => #{<<"x">> => <<"base">>},
                         <<"b">> => <<"x">>}],
          yamerl_constr:string(Yaml, [{detailed_constr, false},
            {map_node_format, map}, {str_node_as_binary, true}])),
        ?_test(begin
            [#yamerl_doc{root = #yamerl_map{pairs = [
                {_, #yamerl_map{pairs = [{Key, _}]}}, {_, Alias}]}}] =
              yamerl_constr:string(Yaml, [{detailed_constr, true}]),
            ?assertMatch(#yamerl_str{text = "x"}, Key),
            ?assertEqual(Key, Alias)
          end)
      ]
    }.

assert_detailed(Yaml, Expected) ->
    [#yamerl_doc{root = #yamerl_map{pairs = [
        {#yamerl_str{text = "a"}, Source},
        {#yamerl_str{text = "b"}, Alias}]}}] =
      yamerl_constr:string(Yaml, [{detailed_constr, true}]),
    ?assertEqual(Expected, shape(Source)),
    ?assertEqual(Source, Alias).

simple({mapping, Pairs}, proplist) ->
    [{Key, simple(Value, proplist)} || {Key, Value} <- Pairs];
simple({mapping, Pairs}, map) ->
    maps:from_list([{list_to_binary(Key), simple(Value, map)}
      || {Key, Value} <- Pairs]);
simple({sequence, Entries}, Format) ->
    [simple(Entry, Format) || Entry <- Entries];
simple({scalar, Text}, proplist) ->
    Text;
simple({scalar, Text}, map) ->
    list_to_binary(Text).

shape(#yamerl_map{pairs = Pairs}) ->
    {mapping, [{Key, shape(Value)}
      || {#yamerl_str{text = Key}, Value} <- Pairs]};
shape(#yamerl_seq{entries = Entries, count = Count}) ->
    ?assertEqual(length(Entries), Count),
    {sequence, [shape(Entry) || Entry <- Entries]};
shape(#yamerl_str{text = Text}) ->
    {scalar, Text}.

fixtures() ->
    Map = {mapping, [{"x", {scalar, "base"}}]},
    [
      {"flow map", "a: &a {x: base}\nb: *a\n", Map},
      {"flow sequence", "a: &a [one, two]\nb: *a\n",
        {sequence, [{scalar, "one"}, {scalar, "two"}]}},
      {"empty flow map", "a: &a {}\nb: *a\n", {mapping, []}},
      {"empty flow sequence", "a: &a []\nb: *a\n", {sequence, []}},
      {"block map", "a: &a\n  x: base\nb: *a\n", Map},
      {"scalar", "a: &a scalar\nb: *a\n", {scalar, "scalar"}},
      {"nested flow map", "a: &a {x: {y: base}}\nb: *a\n",
        {mapping, [{"x", {mapping, [{"y", {scalar, "base"}}]}}]}},
      {"tag before anchor", "a: !!map &a {x: base}\nb: *a\n", Map},
      {"anchor before tag", "a: &a !!map {x: base}\nb: *a\n", Map},
      {"flow map on following line", "a: &a\n  {x: base}\nb: *a\n", Map}
    ].
