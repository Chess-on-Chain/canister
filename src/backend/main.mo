import Chess "lib/chess";
import IcWebSocketCdk "mo:ic-websocket-cdk";
import IcWebSocketCdkState "mo:ic-websocket-cdk/State";
import IcWebSocketCdkTypes "mo:ic-websocket-cdk/Types";
import Map "mo:core/Map";
// import Debug "mo:base/Debug";
// import Nat "mo:base/Nat";
// import Text "mo:base/Text";
// import Debug "mo:base/Debug";
import Pubsub "lib/pubsub";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Bool "mo:base/Bool";
import Time "mo:base/Time";
import Random "mo:core/Random";
import Nat64 "mo:base/Nat64";
import Timer "mo:base/Timer";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import Types "lib/types";
import Helpers "lib/helpers";
import Match "lib/match"

persistent actor {
  // STORAGES
  let users = Map.empty<Principal, Types.User>();
  let matchs = Map.empty<Nat64, Types.Match>();
  var match_count : Nat64 = 1;

  var initial_fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
  var owner = Principal.fromBlob(Blob.fromArray([]));
  var initialized = false;
  var chess_engine_principal = Principal.fromBlob(Blob.fromArray([]));

  transient let rooms = Map.empty<Principal, Bool>();
  transient let invite_rooms = Map.empty<Principal, Principal>();
  transient let on_match = Map.empty<Principal, Bool>();

  // ENDSTORAGES

  transient let random = Random.crypto();
  transient let COUNTDOWN_SECONDS = #seconds 60;

  private func get_or_create_user(user_principal : Principal) : Types.User {
    let user = Map.get<Principal, Types.User>(users, Principal.compare, user_principal);

    switch (user) {
      case null {
        let new_user : Types.User = {
          id = user_principal;
          draw = 0;
          win = 0;
          lost = 0;
          fullname = "Anonymous";
          score = 300;
          is_banned = false;
          username = null;
        };

        Map.add<Principal, Types.User>(users, Principal.compare, user_principal, new_user);

        new_user;
      };
      case (?user) {
        user;
      };
    };
  };

  private func can_join_room(user_principal : Principal) : Bool {
    let user = get_or_create_user(user_principal);
    let is_anonymous = Principal.isAnonymous(user_principal);

    let is_banned = user.is_banned;

    let on_match_exists = switch (Map.get<Principal, Bool>(on_match, Principal.compare, user_principal)) {
      case null {
        false;
      };
      case (?status) {
        status;
      };
    };

    let empty_room = switch (Map.get<Principal, Bool>(rooms, Principal.compare, user_principal)) {
      case null {
        true;
      };
      case _ {
        false;
      };
    };

    empty_room and not on_match_exists and not is_banned and not is_anonymous;
  };

  private func release_match(match_id : Nat64, winner : Text) : Result.Result<Types.Match, Text> {
    Debug.print("RELEASE");

    let match = Map.get<Nat64, Types.Match>(matchs, Nat64.compare, match_id);

    switch (match) {
      case (?match) {
        Timer.cancelTimer(match.timer);

        let new_match = Match.Match(matchs, match.id);
        let new_match_updated = new_match.update({
          moves = null;
          is_white_turn = null;
          winner = ?winner;
          timer = null;
          fen = null;
        });

        switch (new_match_updated) {
          case (#ok(new_match_updated)) {
            #ok(new_match_updated);
          };
          case (#err(text)) {
            #err(text);
          };
        };

      };
      case _ {
        #err("Match not found");
      };
    }

  };

  private func create_match(player_a : Principal, player_b : Principal, is_rank : Bool) : async Result.Result<Types.Match, Text> {
    let now = Nat64.fromIntWrap(Time.now());

    if (not can_join_room(player_a)) {
      return #err("User A can't join room");
    } else if (not can_join_room(player_b)) {
      return #err("User B can't join room");
    };

    let id = match_count;
    match_count += 1;

    let random_value = await* random.nat8();

    var white_player = player_a;
    var black_player = player_b;

    if (random_value % 2 == 0) {
      white_player := player_b;
      black_player := player_a;
    };

    let timer = Timer.setTimer<system>(
      COUNTDOWN_SECONDS,
      func() : async () {
        Debug.print("HARDUH");
        let _ = release_match(id, "black");
      },
    );

    let match : Types.Match = {
      white_player = white_player;
      black_player = black_player;
      id = id;
      is_ranked = is_rank;
      is_white_turn = true;
      fen = initial_fen;
      moves = [{
        fen = initial_fen;
        time = now;
      }];
      time = now;
      winner = "ongoing";
      timer = timer;
    };

    let _ = Map.add<Nat64, Types.Match>(matchs, Nat64.compare, id, match);

    switch (Map.get<Principal, Bool>(on_match, Principal.compare, player_a)) {
      case null {
        Map.add<Principal, Bool>(on_match, Principal.compare, player_a, true);
      };
      case (_) {
        let _ = Map.replace<Principal, Bool>(on_match, Principal.compare, player_a, true);
      };
    };

    #ok(match);
  };

  public func initialize(_owner : Principal, _chess_engine_principal : Principal) {
    assert not initialized;
    owner := _owner;
    chess_engine_principal := _chess_engine_principal;
    initialized := true;
  };

  public shared ({ caller }) func invite_match(friend_principal : Principal) : async () {
    switch (Map.get<Principal, Principal>(invite_rooms, Principal.compare, caller)) {
      case null {
        Map.add<Principal, Principal>(invite_rooms, Principal.compare, caller, friend_principal);
      };
      case (_) {
        let _ = Map.replace<Principal, Principal>(invite_rooms, Principal.compare, caller, friend_principal);
      };
    };
  };

  public shared ({ caller }) func accept_match(friend_principal : Principal) : async Result.Result<Types.Match, Text> {
    let user = get_or_create_user(caller);

    if (user.is_banned) {
      return #err("Your has been banned");
    };

    switch (Map.get<Principal, Principal>(invite_rooms, Principal.compare, friend_principal)) {
      case null {
        return #err("Can't join room");
      };
      case (?self) {
        if (self == caller) {
          Map.remove<Principal, Principal>(invite_rooms, Principal.compare, friend_principal);

          let match = await create_match(
            friend_principal,
            caller,
            false,
          );

          switch (match) {
            case (#ok(match)) {
              return #ok(match);
            };
            case (#err(text)) {
              return #err(text);
            };
          }

        } else {
          return #err("Can't join room");
        };

      };
    };
  };

  public shared ({ caller }) func make_match(is_rank : Bool) : async Result.Result<Types.MatchCreated, Text> {
    if (not can_join_room(caller)) {
      return #err("Can't make match");
    };

    let all_rooms = Map.entries<Principal, Bool>(rooms);

    for ((opponent, opponent_is_rank) in all_rooms) {
      if (opponent_is_rank == is_rank) {
        Map.remove<Principal, Bool>(rooms, Principal.compare, opponent);

        let match = await create_match(opponent, caller, is_rank);

        switch (match) {
          case (#ok(match)) {
            return #ok(#match(match));
          };
          case (#err(text)) {
            return #err(text);
          };
        };
      };
    };

    Map.add(rooms, Principal.compare, caller, is_rank);
    return #ok(#text("Waiting opponent..."));
  };

  public shared ({ caller }) func make_move(match_id : Nat64, from_position : Text, to_position : Text, promotion : ?Text) : async Result.Result<Types.Match, Text> {
    let position = switch (Helpers.translate_move(from_position), Helpers.translate_move(to_position)) {
      case (#ok(from_position_int), #ok(to_position_int)) {
        #ok(from_position_int, to_position_int);
      };
      case (#err(text), _) {
        #err(text);
      };
      case (_, #err(text)) {
        #err(text);
      };
    };

    let match_object = Match.Match(matchs, match_id);

    let now = Time.now();

    switch (match_object.get(), position, caller) {
      case (_, #err(text), _) {
        #err(text);
      };
      case (?match, #ok(from_position_int, to_position_int), caller) {
        Debug.print(match.winner);
        switch (match.is_white_turn, match.winner, caller == match.white_player, caller == match.black_player) {
          case (_, "ongoing", false, false) {
            return #err("Forbidden");
          };
          case (false, "ongoing", true, _) {
            return #err("Forbidden");
          };
          case (true, "ongoing", false, _) {
            return #err("Forbidden");
          };
          case (_, "ongoing", _, _) {};
          case _ {
            return #err("match finish");
          };
        };

        let result = await Chess.next_move_and_status(
          chess_engine_principal,
          match.fen,
          from_position_int,
          to_position_int,
          promotion,
        );

        let moves = Array.append<Types.Move>(match.moves, [{ fen = match.fen; time = Nat64.fromIntWrap(now) }]);

        let updated_match = match_object.update({
          fen = ?result.fen;
          is_white_turn = ?(not match.is_white_turn);
          moves = ?moves;
          timer = null;
          winner = null;
        });

        let status = result.status % 10;
        let turn = status / 10;
        let game_status = status % 10;

        switch (game_status, turn) {
          case (1, _) {
            release_match(match_id, "draw");
          };
          case (2, 1) {
            release_match(match_id, "black");
          };
          case (2, 2) {
            release_match(match_id, "white");
          };
          case (_, _) {
            // #err("Unknown err");
            updated_match;
          };
        }

      };
      case (null, _, _) {
        #err("Match not found");
      };
    }

  };

  public shared ({ caller }) func cancel_match_room() : async () {
    Map.remove<Principal, Bool>(rooms, Principal.compare, caller);
  };

  public func ping() : async (Text) {
    "PONG";
  };

  transient let params = IcWebSocketCdkTypes.WsInitParams(null, null);
  transient let ws_state = IcWebSocketCdkState.IcWebSocketState(params);

  transient let handlers = IcWebSocketCdkTypes.WsHandlers(
    ?Pubsub.on_open,
    ?Pubsub.on_message,
    ?Pubsub.on_close,
  );

  transient let ws = IcWebSocketCdk.IcWebSocket(ws_state, params, handlers);

  public shared ({ caller }) func ws_open(args : IcWebSocketCdk.CanisterWsOpenArguments) : async IcWebSocketCdk.CanisterWsOpenResult {
    await ws.ws_open(caller, args);
  };

  // method called by the Ws Gateway when closing the IcWebSocket connection
  public shared ({ caller }) func ws_close(args : IcWebSocketCdk.CanisterWsCloseArguments) : async IcWebSocketCdk.CanisterWsCloseResult {
    await ws.ws_close(caller, args);
  };

  // // method called by the frontend SDK to send a message to the canister
  // public shared ({ caller }) func ws_message(args : IcWebSocketCdk.CanisterWsMessageArguments, msg : ?AppMessage) : async IcWebSocketCdk.CanisterWsMessageResult {
  //   await ws.ws_message(caller, args, msg);
  // };

  // method called by the WS Gateway to get messages for all the clients it serves
  public shared query ({ caller }) func ws_get_messages(args : IcWebSocketCdk.CanisterWsGetMessagesArguments) : async IcWebSocketCdk.CanisterWsGetMessagesResult {
    ws.ws_get_messages(caller, args);
  };
};
