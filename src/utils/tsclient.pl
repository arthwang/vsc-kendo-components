:- module(tsclient, [
    run_pro/0,
    run_core/0
    ]).
:- use_module(library(process)).
:- use_module(library(http/json)).
:- use_module(library(pcre)).
:- use_module(library(dialect/hprolog)).
:- use_module(library(lists)).
:- use_module(library(http/http_open)).
:- use_module(library(xpath)).
:- use_module(library(apply)).

:- dynamic cached_widgets/1,
        overview_url/2,
        overview/2,
        dict/1.

pro_widgets(["kendoEditor", "kendoUpload", "kendoTreeView", "kendoGantt", "kendoScheduler", "kendoGrid", "kendoSpreadsheet", "kendoPivotGrid", "kendoTreeList", "kendoChats", "kendoChart", "kendoSparkline", "kendoStockChart", "kendoTreeMap", "kendoBarcode", "kendoQRCode", "kendoLinearGauge", "kendoRadialGauge", "kendoDiagram", "kendoMap", "kendoMediaPlayer"]).
doc_root('https://docs.telerik.com/kendo-ui/controls/').
category('data-management').
category('editors').
category('charts').
category('gauges').
category('barcodes').
category('diagram-and-maps').
category('scheduling').
category('layout').
category('navigation').
category('conversational-ui').
category('interactivity').
category('media').
category('hybrid').

saved_file('src/utils/overviews.pl').
saved_file('src/utils/overviewUrls.pl').
saved_file('out/src/features/kendoui.json').

clean_files :-
    saved_file(File),
    exists_file(File),
    delete_file(File),
    fail.
clean_files. 
    
    
    
tmpFile(File) :-
    working_directory(Dir, Dir),
    atom_concat(Dir, '/src/utils/.tmp.ts', File).

init :-
    clean_files,
    retractall(cached_widgets(_)),
    retractall(overview_url(_,_)),
    retractall(overview(_,_)),
    retractall(dict(_)).

run_pro :-
    run(true).
run_core :-
    run(false).

run(IsPro) :-
    init,
    find_overview_urls(IsPro),
    find_overviews,
    gen_snippets,
    gen_kendo_dict(IsPro).

    
get_kendo_version(Version) :-
    setup_call_cleanup(
        open('node_modules/@types/kendo-ui/index.d.ts', read, DTS), 
        (   read_line_to_string(DTS, Line),
            re_matchsub("v([\\d\\.]+)$", Line, Dict, []),
            Version = Dict.1
        ), 
        close(DTS)
    ).
    
write_prefix(Prefix) :-
    tmpFile(File),
    setup_call_cleanup(
       open(File, write, Stream), 
       format(Stream, Prefix, []),
       close(Stream)
    ).

tss_request(Prefix, Command, ArgsDict, ResponseDict) :-
    tmpFile(TSFile),
    write_prefix(Prefix),
    process_create(path(tsserver), [], [stdin(pipe(TSSIn)), stdout(pipe(TSSOut)), process(PID)]),
    format(TSSIn,
           '{"seq":0,"type":"request","command":"open","arguments":{"file":"~s"}}~n',
           [TSFile]),
    InDict = _{
        seq: 1,
        type: "request",
        command: Command
    },
    NewArgs = ArgsDict.put(file, "~s"),
    NewDict = InDict.put(arguments, NewArgs),
    atom_json_dict(DictStr1, NewDict, []),
    re_replace('[\r\n\s]'/g, '', DictStr1, DictStr),
    format(TSSIn, DictStr, [TSFile]),
    nl(TSSIn),
    close(TSSIn),
    read_lines_to_codes(TSSOut, LCodes),
    flatten(LCodes, Codes),
    find_respone(Codes, ResponseDict),
    close(TSSOut),
    process_wait(PID, Status),
    format('~s done for "~s" with satus:~w~n', [Command, Prefix, Status]), !.

read_lines_to_codes(Out, [Line|Lines]) :-
    read_line_to_codes(Out, Line),
    Line \= end_of_file, !,
    read_lines_to_codes(Out, Lines).
read_lines_to_codes(_, []) :- !. 

find_respone(Codes, ResponseDict) :-
    balance('{', '}', Codes, MatchedLIndex, MatchedRIndex),
    string_codes(String, Codes),
    (
        length(Codes, Len),
        After is Len - MatchedRIndex,
        B1 is MatchedLIndex - 1,
        sub_string(String, B1, _, After, SubStr),
        atom_json_dict(SubStr, ResponseDict, []),
        dict_keys(ResponseDict, Keys),
        memberchk(request_seq, Keys),
        ResponseDict.request_seq =:= 1, !
    ;   drop(MatchedRIndex, Codes, RestCodes),
        find_respone(RestCodes, ResponseDict)
    ).
    
%% Left and Right must be a char
balance(Left, Right, CodesIn, LFirstIndex, RMatchedIndex) :-
    atom_codes(Left, [LCode]),
    atom_codes(Right, [RCode]),
    nth1(LFirstIndex, CodesIn, LCode), !,
    nb_setval(balanced, 1),
    drop(LFirstIndex, CodesIn, RestCodes),
    N is LFirstIndex + 1,
    balance1(LCode, RCode, RestCodes, N, RMatchedIndex), !.
balance1(LCode, RCode, [RCode|Codes], N, RMatchedIndex) :-
    nb_getval(balanced, Balanced),
    (
        Balanced =:= 1, 
        RMatchedIndex is N,!
    ;
        nb_getval(balanced, Balanced),
        B1 is Balanced - 1,
        nb_setval(balanced, B1),
        N1 is N + 1,
        balance1(LCode, RCode, Codes, N1, RMatchedIndex)
    ).
balance1(LCode, RCode, [LCode|Codes], N, RMatchedIndex) :-
    nb_getval(balanced, Balanced),
    B1 is Balanced + 1,
    nb_setval(balanced, B1),
    N1 is N + 1,
    balance1(LCode, RCode, Codes, N1, RMatchedIndex).
balance1(LCode, RCode, [_|Codes], N, RMatchedIndex) :-
    N1 is N + 1,
    balance1(LCode, RCode, Codes, N1, RMatchedIndex).
balance1(_, _, [], _, _) :- fail.

find_widgets(_, Names) :-
    cached_widgets(Names), !.
find_widgets(IsPro, Names) :-
    tss_request('$.fn.kendo', 'completions', _{line:1, offset: 11}, ResponseDict),
    AllCompletions = ResponseDict.body,
    maplist(response_name, AllCompletions, AllNames),
    (   IsPro == true
    ->  include(starts_with('kendo'), AllNames, Names)
    ;   pro_widgets(ProWidgets),
        include(is_core_widget(ProWidgets), AllNames, Names)
    ),
    retractall(cached_widgets(_)),
    assert(cached_widgets(Names)).

is_core_widget(ProWidgets, Name) :- 
    starts_with("kendo", Name),
    \+ memberchk(Name, ProWidgets).

response_name(Widget, Widget.name).
    
find_overview_urls(IsPro) :-
    find_widgets(IsPro, Widgets),
    setup_call_cleanup(
        open('src/utils/overviewUrls.pl', append, Out),
        foreach(member(Widget, Widgets), find_path(Out, Widget)),
        close(Out)
    ).
    
find_overviews :-
    retractall(overview_url(_,_)),
    consult('src/utils/overviewUrls.pl'),
    setup_call_cleanup(
        open('src/utils/overviews.pl', append, Out), 
        find_doc_descriptions(Out), 
        close(Out)
    ).
    
find_doc_descriptions(Out) :-
    overview_url(Widget, Url),
    (   Url \= notfound
    ->  load_html(Url, Dom, []),
        once(xpath(Dom, //article/p(text), Overview)),
        format(Out, 'overview(~q, ~q).~n', [Widget, Overview])
    ;   format(Out, 'overview(~q, ~q).~n', [Widget, "notfound"])
    ),
    fail.
find_doc_descriptions(_). 
    
find_path(Out, Name) :-
    writeln('try to find doc path for':Name),
    sub_string(Name, 5, _, 0, Widget),
    string_lower(Widget, LWidget),
    doc_root(Root),
    category(Ctgry),
    (   Ctgry \= hybrid 
    ->    atomic_list_concat([Root, Ctgry, '/', LWidget, '/overview'], Path)
    ;     atom_concat(mobile, MWidget, LWidget),
          atomic_list_concat([Root, Ctgry, '/', MWidget, '/', MWidget], Path)
    ),
    writeln('try':Path),
    catch(
        load_html(Path, _, []),
        _,    
        fail
    ),
    writeln(LWidget:Path), 
    format(Out, 'overview_url(~q, ~q).~n', [Widget, Path]),!.
find_path(Out, Name) :-
    sub_string(Name, 5, _, 0, Widget),
    format(Out, 'overview_url(~q, ~q).~n', [Widget, notfound]),!.
    
gen_snippets :-
    retractall(overview(_, _)),
    nb_linkval(snippetsDict, _{}),
    consult('src/utils/overviews.pl'),
    overview(Widget, Overview),
    nb_getval(snippetsDict, DictIn),
    string_to_atom(Widget, WidgetAtom),
    re_replace("([a-z])([A-Z])"/g, "$1-$2", Widget, TagName1),
    string_lower(TagName1, TagName2),
    (   atom_concat('mobile-', TagName, TagName2)
    ->  atom_concat('<km-', TagName, Prefix),
        atomic_list_concat([Prefix, '$0></km-', TagName, '>'], Body)
    ;   atom_concat('<k-', TagName2, Prefix),
        atomic_list_concat([Prefix, '$0></k-', TagName2, '>'], Body)
    ),
    (   Overview == notfound
    ->  atom_concat('kendo ui core widget ', Widget, Desc)
    ;   Desc = Overview    
    ),
    DictOut = DictIn.put(WidgetAtom, _{
        prefix: Prefix,
        body: Body,
        description: Desc
    }),
    nb_linkval(snippetsDict, DictOut),
    fail.
gen_snippets :-
    nb_getval(snippetsDict, Dict1),
    Dict2 = _{},
    gen_html5_snippet(Dict3),
    Dict4 = Dict2.put('html5:kendo', Dict3),
    setup_call_cleanup(
        open('snippets/kendoui_core.json', write, Out), 
        json_write_dict(Out, Dict4, []),
        close(Out)
    ),
    setup_call_cleanup(
        open('snippets/kendoui_tags.json', write, Out1), 
        json_write_dict(Out1, Dict1, []),
        close(Out1)
    ).

gen_html5_snippet(Dict) :-
    get_kendo_version(Version),
    set_prolog_flag(back_quotes, string),
    format(string(Body),
    `[
      "<!DOCTYPE html>",
      "<html lang='en'>",
      "<head>",
      "\t<meta charset='UTF-8'>",
      "\t<meta name='viewport' content='width=device-width, initial-scale=1.0'>",
      "\t<meta http-equiv='X-UA-Compatible' content='ie=edge'>",
      "\t<title>$1</title>",
      "\t<link rel='stylesheet' href='http://kendo.cdn.telerik.com/2018.3.911/styles/kendo.common.min.css'/>",
      "\t<link rel='stylesheet' href='http://kendo.cdn.telerik.com/2018.3.911/styles/kendo.default.min.css'/>",
      "\t<link rel='stylesheet' href='http://kendo.cdn.telerik.com/2018.3.911/styles/kendo.mobile.all.min.css'/>",
      "\t<script src='http://kendo.cdn.telerik.com/2018.3.911/js/jquery.min.js'></script>",
      "\t<script src='http://kendo.cdn.telerik.com/2018.3.911/js/kendo.all.min.js'></script>",
      "\t<script src='/node_modules/kendoui-core-components/dist/kendo-core-components.min.js'></script>",
      "</head>",
      "<body>",
      "\t$0",
      "</body>",
      "</html>"
    ]`, 
    [Version, Version, Version, Version, Version]),
    Dict = _{
        prefix: "html5:kendoui",
        body: Body, 
        description: "HTML 5 skeleton for Kendo UI core cdn resource."
    }.
gen_kendo_dict(IsPro) :-
    retractall(dict(_)),
    find_widgets(IsPro, Names),
    member(Name, Names),
    atom_concat("kendo", Widget, Name),
    format('Handling ~s...~n', [Widget]),
    request_completion_details(Widget, false),
    fail.
gen_kendo_dict(_) :- 
    join_dict(Dict),
    setup_call_cleanup(
        open('out/src/features/kendoui.json', write, Out), 
        json_write_dict(Out, Dict),
        close(Out)
    ).

join_dict(DictOut) :-
    findall(Dict, dict(Dict), Dicts),
    foldl(join_dict, Dicts, _{}, DictOut).
join_dict(Dict, DictIn, DictOut) :-
    findall(Key-Value, leaf_key_value(Dict, Key, Value), KVals),
    foldl(add_a_key_val, KVals, DictIn, DictOut).
    
add_a_key_val(K-V, DictIn, DictOut) :-
    DictOut = DictIn.put(K, V).

request_completion_details(PrefixIn, IsProperty) :-
    (   IsProperty == true
    ->  Prefix = PrefixIn
    ;   atomic_list_concat(['$.fn.kendo', PrefixIn, '({'], Prefix)
    ),
    catch(
        (   tss_request(Prefix, completions, _{line:1, offset:200}, ComplDict),
            Completions = ComplDict.body,
            maplist(response_name, Completions, PropNames),
            tss_request(Prefix, completionEntryDetails, _{line:2, offset:1, entryNames: PropNames}, DetailDict),
            DetailBody = DetailDict.body,
            maplist(property_display_pair, DetailBody, KVPairs),
            foldl(add_to_dict(Prefix), KVPairs, _{}, DictOut1),
            (   IsProperty == false
            ->  KVPairs = [KeyPath-_|_],
                KeyPath =.. [/, Options, _],
                term_string(Options, OptsStr1),
                re_replace("/"/g, ".", OptsStr1, OptsStr2),
                re_replace("'"/g, "", OptsStr2, OptsStr),
                string_to_atom(PrefixIn, PFA),
                writeq(options/PFA:OptsStr),nl,
                DictOut = DictOut1.put(options/PFA, OptsStr)
            ;   DictOut = DictOut1
            ),
            assert(dict(DictOut))
        ),
        _, 
        true).

add_to_dict(Prefix, Key-Val, DictIn, DictOut) :-
    (   string_concat("(property)", _, Val)
    ->  re_split("\\s*\\|\\s*|\\??:\\s*", Val, ValLst1),
        include(starts_with("kendo."), ValLst1, ValLst),
        (   ValLst \= []
        ->  leaf_key(Key, Leaf),
            (   atom_concat(_, '[]', Val)
            ->  atomic_list_concat([Prefix, Leaf, ':[{'], NewPrefix)
            ;   atomic_list_concat([Prefix, Leaf, ':{'], NewPrefix)
            ),
            request_completion_details(NewPrefix, true)
        ;   true
        )
    ;   true
    ),
    DictOut = DictIn.put(Key, Val), !.
add_to_dict(_, _, Dict, Dict).

starts_with(Start, String) :-
    string_concat(Start, _, String).
property_display_pair(PropDict, Key-Value) :-
    merge_display_text(PropDict.displayParts, DispTxt),
    re_split("\\?", DispTxt, [Key1, Sep, Value1]),
    re_split("\\s+", Key1, [Kind, _, Key2]),
    atomic_list_concat([Kind, Sep, Value1], Value),
    re_split("\\.", Key2, Keys1),
    reverse(Keys1, Keys2),
    strings_to_term(Keys2, Key), !.
property_display_pair(_, null-null).

merge_display_text(DisplayParts, DispTxt) :-
    maplist(display_text, DisplayParts, Txts),
    atomic_list_concat(Txts, DispTxt).

display_text(Type, Type.text).
    
strings_to_term([Str, "."|ST], TT/Atom) :-
    string_to_atom(Str, Atom),
    strings_to_term(ST, TT), !.
strings_to_term([Str], Atom) :-
    string_to_atom(Str, Atom), !.

leaf_key(KeyPath, LeafKey) :-
    term_string(KeyPath, PathStr),
    re_split("/", PathStr, KeyLst),
    reverse(KeyLst, [LeafKey|_]).

leaf_key_value(Dict, Key, Value) :-
    leaf_key_value(Dict, null, Key, Value).
    % Key1 =.. [/, null, Key].
leaf_key_value(Dict, Ancestor, Key, Value) :-
    dict_keys(Dict, Keys),
    member(Key1, Keys),
    Value1 = Dict.Key1,
    (   Ancestor == null
    ->  Path = Key1
    ;   Path = Ancestor/Key1
    ),
    (   is_dict(Value1)
    ->  leaf_key_value(Value1, Path, Key, Value)
    ;   Key = Path, Value = Value1
    ).
    