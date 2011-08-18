-module(http_prebind).
-author('andy@automattic.com').
-include("jlib.hrl").
-include("ejabberd_http.hrl").
-include("ejabberd.hrl").
-export([process/2]).

process([Login], #request{auth = Auth, ip = IP}) ->
  case get_auth(Auth) of
    {"AUTH_USER", "EJABBERD_DOMAIN"} ->
      {201, [], bind(Login, IP)};
    _ ->
      {401, [{"WWW-Authenticate", "basic realm=\"EJABBERD_DOMAIN\""}],"Unauthorized"}
  end;

process(_LocalPath, _Request) ->
  {403, [], "Forbidden"}.

bind(Login, IP) ->
  %% the Rid is the request id, and it starts with getting a random number from a string
  Rid = list_to_integer(randoms:get_string()),
  %% gotta increment it for each message.
  Rid1 = integer_to_list(Rid + 1),
  {xmlelement, "body", Attrs1, _} = process_request("<body rid='"++Rid1++"' xmlns='http://jabber.org/protocol/httpbind' to='EJABBERD_DOMAIN' xml:lang='en' wait='60' hold='1' window='5' content='text/xml; charset=utf-8' ver='1.6' xmpp:version='1.0' xmlns:xmpp='urn:xmpp:xbosh'/>", IP),

  # gets the Session ID and Auth Id from the auth request
  {value, {_, Sid}} = lists:keysearch("sid", 1, Attrs1),
  {value, {_, AuthID}} = lists:keysearch("authid", 1, Attrs1),

  # this is the base64 auth sent to ejabberd
  Rid2 = integer_to_list(Rid + 2),
  Auth = base64:encode_to_string(AuthID++[0]++Login++[0]++"AUTH_PASSWORD"),
  process_request("<body rid='"++Rid2++"' xmlns='http://jabber.org/protocol/httpbind' sid='"++Sid++"'><auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' mechanism='PLAIN'>"++Auth++"</auth></body>", IP),

  Rid3 = integer_to_list(Rid + 3),
  process_request("<body rid='"++Rid3++"' xmlns='http://jabber.org/protocol/httpbind' sid='"++Sid++"' to='EJABBERD_DOMAIN' xml:lang='en' xmpp:restart='true' xmlns:xmpp='urn:xmpp:xbosh'/>", IP),

  Rid4 = integer_to_list(Rid + 4),
  {_,_,_,[{_,_,_,[{_,_,_,[{_,_,_,[{_,SJID}]}]}]}]} = process_request("<body rid='"++Rid4++"' xmlns='http://jabber.org/protocol/httpbind' sid='"++Sid++"'><iq type='set'><bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'/></iq></body>", IP),

  Rid5 = integer_to_list(Rid + 5),
  process_request("<body rid='"++Rid5++"' xmlns='http://jabber.org/protocol/httpbind' sid='"++Sid++"'><iq type='set'><session xmlns='urn:ietf:params:xml:ns:xmpp-session'/></iq></body>", IP),

  %% here's the return sent back over http.
  binary_to_list(SJID) ++ "\n" ++ Sid ++ "\n" ++ integer_to_list(Rid + 6).

process_request(Request, IP) ->
  {_, _, Response} = ejabberd_http_bind:process_request(Request, IP),
  xml_stream:parse_element(lists:flatten(Response)).

get_auth(Auth) ->
  case Auth of
    {SJID, P} ->
      case jlib:string_to_jid(SJID) of
        error ->
          unauthorized;
        #jid{user = U, server = S} ->
          case ejabberd_auth:check_password(U, S, P) of
            true ->
              {U, S};
            false ->
              unauthorized
          end
      end;
    _ ->
      unauthorized
  end.
