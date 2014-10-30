-module(http_prebind).
-author('andy@automattic.com').
-include("/root/dev/ejabberd/include/jlib.hrl").
-include("/root/dev/ejabberd/include/ejabberd_http.hrl").
-include("/root/dev/ejabberd/include/ejabberd.hrl").
-export([process/2]).

%process([Login], #request{auth = Auth, ip = IP}) ->
%  case get_auth(Auth) of
%    {"AUTH_USER", "EJABBERD_DOMAIN"} ->
%      {201, [], bind(Login, IP)};
%    _ ->
%      {401, [{"WWW-Authenticate", "basic realm=\"EJABBERD_DOMAIN\""}],"Unauthorized"}
%  end;

% process([Login], #request{auth = Auth, ip = IP}) ->
%   {201, [], get_auth_fer(Auth)};


process([Login], #request{auth = Auth, ip = IP}) ->
 case get_auth(Auth) of
   {_, _, _} ->
     {User, Domain, Password} = get_auth(Auth),
     {201, [], bind(Login, IP, User, Domain, Password)};
   _ ->
     {401, [{"WWW-Authenticate", "basic realm=\"EJABBERD_DOMAIN\""}],"Unauthorized"}
 end;

process(_LocalPath, _Request) ->
  {403, [], "Forbidden"}.


bin_to_num(Bin) ->
    N = binary_to_list(Bin),
    case string:to_float(N) of
        {error,no_float} -> list_to_integer(N);
        {F,_Rest} -> F
    end.

% get_xml_part(Xml, Key) ->
%   Pos = string:str(Xml, Key),


bind(Login, IP, User, Domain, Password) ->
  %% the Rid is the request id, and it starts with getting a random number from a string
  % Rid = list_to_integer(randoms:get_string()),
  Rid = bin_to_num(randoms:get_string()),

  %% gotta increment it for each message.
  Rid1 = integer_to_list(Rid + 1),
  % {xmlelement, "body", Attrs1, _} = process_request("<body rid='"++Rid1++"' xmlns='http://jabber.org/protocol/httpbind' to='" ++ binary_to_list(Domain) ++ "' xml:lang='en' wait='60' hold='1' window='5' content='text/xml; charset=utf-8' ver='1.6' xmpp:version='1.0' xmlns:xmpp='urn:xmpp:xbosh'/>", IP),
  % {xmlelement, _, Attrs1, _} = process_request("<body rid='"++Rid1++"' xmlns='http://jabber.org/protocol/httpbind' to='" ++ binary_to_list(Domain) ++ "' xml:lang='en' wait='60' hold='1' window='5' content='text/xml; charset=utf-8' ver='1.6' xmpp:version='1.0' xmlns:xmpp='urn:xmpp:xbosh'/>", IP),
  {_, _, Attrs1, _} = process_request("<body rid='"++Rid1++"' xmlns='http://jabber.org/protocol/httpbind' to='" ++ binary_to_list(Domain) ++ "' xml:lang='en' wait='60' hold='1' window='5' content='text/xml; charset=utf-8' ver='1.6' xmpp:version='1.0' xmlns:xmpp='urn:xmpp:xbosh'/>", IP),  

  % gets the Session ID and Auth Id from the auth request
  % {value, {_, Sid}} = lists:keysearch("sid", 1, Attrs1),
  % {value, {_, AuthID}} = lists:keysearch("authid", 1, Attrs1),
  {value, {_, Sid}} = lists:keysearch(<<"sid">>, 1, Attrs1),
  {value, {_, AuthID}} = lists:keysearch(<<"authid">>, 1, Attrs1),

  % this is the base64 auth sent to ejabberd
  Rid2 = integer_to_list(Rid + 2),
  Auth = base64:encode_to_string(binary_to_list(AuthID)++[0]++binary_to_list(Login)++[0]++binary_to_list(Password)),
  process_request("<body rid='"++Rid2++"' xmlns='http://jabber.org/protocol/httpbind' sid='"++binary_to_list(Sid)++"'><auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' mechanism='PLAIN'>"++Auth++"</auth></body>", IP),

  Rid3 = integer_to_list(Rid + 3),
  process_request("<body rid='"++Rid3++"' xmlns='http://jabber.org/protocol/httpbind' sid='"++binary_to_list(Sid)++"' to='" ++ binary_to_list(Domain) ++ "' xml:lang='en' xmpp:restart='true' xmlns:xmpp='urn:xmpp:xbosh'/>", IP),

  Rid4 = integer_to_list(Rid + 4),
  {_,_,_,[{_,_,_,[{_,_,_,[{_,_,_,[{_,SJID}]}]}]}]} = process_request("<body rid='"++Rid4++"' xmlns='http://jabber.org/protocol/httpbind' sid='"++binary_to_list(Sid)++"'><iq type='set'><bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'/></iq></body>", IP),

  Rid5 = integer_to_list(Rid + 5),
  process_request("<body rid='"++Rid5++"' xmlns='http://jabber.org/protocol/httpbind' sid='"++binary_to_list(Sid)++"'><iq type='set'><session xmlns='urn:ietf:params:xml:ns:xmpp-session'/></iq></body>", IP),

  %% here's the return sent back over http.
  binary_to_list(SJID) ++ "\n" ++ binary_to_list(Sid) ++ "\n" ++ integer_to_list(Rid + 6).




process_request(Request, IP) ->
  {_, _, Response} = ejabberd_http_bind:process_request(Request, IP),
  % Response2 = binary_to_list(Response),
  % xml_stream:parse_element(lists:flatten(Response)).
  xml_stream:parse_element(Response).
  % Response.

% get_auth_fer(Auth) ->
%   case Auth of
%     {SJID, P} ->
%       {SJID, P};
%     _ ->
%       unauthorized
%   end.


get_auth(Auth) ->
  case Auth of
    {SJID, P} ->
      case jlib:string_to_jid(SJID) of
        error ->
          unauthorized;
        #jid{user = U, server = S} ->
          case ejabberd_auth:check_password(U, S, P) of
            true ->
              {U, S, P};
            false ->
              unauthorized
          end
      end;
    _ ->
      unauthorized
  end.









% {xmlel,<<"body">>,[{<<"xmlns">>,<<"http://jabber.org/protocol/httpbind">>},{<<"xmlns:xmpp">>,<<"urn:xmpp:xbosh">>},{<<"xmlns:stream">>,<<"http://etherx.jabber.org/streams">>},{<<"sid">>,<<"2559023af85122de8c45250bb226b990f5279bf5">>},{<<"wait">>,<<"60">>},{<<"requests">>,<<"2">>},{<<"inactivity">>,<<"30">>},{<<"maxpause">>,<<"120">>},{<<"polling">>,<<"2">>},{<<"ver">>,<<"1.8">>},{<<"from">>,<<"li797-4.members.linode.com">>},{<<"secure">>,<<"true">>},{<<"authid">>,<<"2777769369">>},{<<"xmpp:ve...">>,...}],...} in http_prebind:bind/5 line 47


% bind(Login, IP) ->
%   %% the Rid is the request id, and it starts with getting a random number from a string
%   Rid = list_to_integer(randoms:get_string()),
%   %% gotta increment it for each message.
%   Rid1 = integer_to_list(Rid + 1),
%   {xmlelement, "body", Attrs1, _} = process_request("<body rid='"++Rid1++"' xmlns='http://jabber.org/protocol/httpbind' to='EJABBERD_DOMAIN' xml:lang='en' wait='60' hold='1' window='5' content='text/xml; charset=utf-8' ver='1.6' xmpp:version='1.0' xmlns:xmpp='urn:xmpp:xbosh'/>", IP),

%   % gets the Session ID and Auth Id from the auth request
%   {value, {_, Sid}} = lists:keysearch("sid", 1, Attrs1),
%   {value, {_, AuthID}} = lists:keysearch("authid", 1, Attrs1),

%   % this is the base64 auth sent to ejabberd
%   Rid2 = integer_to_list(Rid + 2),
%   Auth = base64:encode_to_string(AuthID++[0]++Login++[0]++"AUTH_PASSWORD"),
%   process_request("<body rid='"++Rid2++"' xmlns='http://jabber.org/protocol/httpbind' sid='"++Sid++"'><auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' mechanism='PLAIN'>"++Auth++"</auth></body>", IP),

%   Rid3 = integer_to_list(Rid + 3),
%   process_request("<body rid='"++Rid3++"' xmlns='http://jabber.org/protocol/httpbind' sid='"++Sid++"' to='EJABBERD_DOMAIN' xml:lang='en' xmpp:restart='true' xmlns:xmpp='urn:xmpp:xbosh'/>", IP),

%   Rid4 = integer_to_list(Rid + 4),
%   {_,_,_,[{_,_,_,[{_,_,_,[{_,_,_,[{_,SJID}]}]}]}]} = process_request("<body rid='"++Rid4++"' xmlns='http://jabber.org/protocol/httpbind' sid='"++Sid++"'><iq type='set'><bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'/></iq></body>", IP),

%   Rid5 = integer_to_list(Rid + 5),
%   process_request("<body rid='"++Rid5++"' xmlns='http://jabber.org/protocol/httpbind' sid='"++Sid++"'><iq type='set'><session xmlns='urn:ietf:params:xml:ns:xmpp-session'/></iq></body>", IP),

%   %% here's the return sent back over http.
%   binary_to_list(SJID) ++ "\n" ++ Sid ++ "\n" ++ integer_to_list(Rid + 6).

