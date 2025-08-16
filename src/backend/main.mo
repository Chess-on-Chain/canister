import Chess "lib/chess";
import Map "mo:core/Map";
import Message "lib/message";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Bool "mo:base/Bool";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Timer "mo:base/Timer";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import Buffer "mo:base/Buffer";
import Nat16 "mo:base/Nat16";
import Types "lib/types";
import Helpers "lib/helpers";
import Match "lib/match";
import Random "lib/random";
import User "lib/user";

persistent actor {
  // STORAGES
  let users = Map.empty<Principal, Types.User>();
  let matchs = Map.empty<Nat64, Types.Match>();
  var unfinished_matchs : [Nat64] = [];
  var match_count : Nat64 = 1;

  var initial_fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
  var owner = Principal.fromBlob(Blob.fromArray([]));
  var initialized = false;
  var chess_engine_principal = Principal.fromBlob(Blob.fromArray([]));

  transient let messages = Buffer.Buffer<Types.WebsocketMessageQueue>(0);
  transient let rooms = Map.empty<Principal, Bool>();
  transient let invite_rooms = Map.empty<Principal, Principal>();
  transient let on_match = Map.empty<Principal, Bool>();
  transient let TIMEOUT_MATCH_NANOSECONDS : Nat64 = 60000000000; // 60 seconds

  // ENDSTORAGES

  // cronjob dieksesui dibawah
  private func cronjob() : async () {
    Debug.print("CRONJOB EXECUTED!");
    let now = Nat64.fromIntWrap(Time.now());

    var new_unfinished_matchs : [Nat64] = [];

    for (match_id in unfinished_matchs.vals()) {
      let match = Match.Match(matchs, match_id).get();

      switch (match) {
        case (?match) {
          let distance = now - match.last_move;

          if (distance >= TIMEOUT_MATCH_NANOSECONDS) {
            ignore release_match(match_id, if (match.is_white_turn) "black" else "white");
          } else {
            new_unfinished_matchs := Array.append(new_unfinished_matchs, [match_id]);
            // masukan kembali ke antrian
          };

        };
        case _ {};
      };

      if (Array.size(unfinished_matchs) != Array.size(new_unfinished_matchs)) {
        unfinished_matchs := new_unfinished_matchs;
      };
    };
  };

  private func get_or_create_user(user_principal : Principal) : Types.User {
    let user = Map.get<Principal, Types.User>(users, Principal.compare, user_principal);

    switch (user) {
      case null {
        let user : Types.User = {
          id = user_principal;
          draw = 0;
          win = 0;
          lost = 0;
          fullname = "Anonymous";
          score = 300;
          is_banned = false;
          username = null;
          country = null;
          photo = null;
        };

        User.insert(users, user_principal, user);

        user;
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

  private func release_match(match_id : Nat64, winner : Text) : Types.Match {
    Debug.print("RELEASE: " # winner);

    // let match = Map.get<Nat64, Types.Match>(matchs, Nat64.compare, match_id);
    let match_object = Match.Match(matchs, match_id);

    switch (match_object.get()) {
      case (?match) {
        let new_match = match_object.update({
          moves = null;
          is_white_turn = null;
          winner = ?winner;
          fen = null;
          last_move = null;
        });

        let white_player_object = User.User(users, match.white_player);
        let black_player_object = User.User(users, match.black_player);

        switch (new_match, white_player_object.get(), black_player_object.get()) {
          case (#ok(new_match), ?_white_player, ?_black_player) {
            let white_player_data = {
              var incr_win : Nat16 = 0;
              var incr_lost : Nat16 = 0;
              var incr_draw : Nat16 = 0;
              var score = null;
            };

            let black_player_data = {
              var incr_win : Nat16 = 0;
              var incr_lost : Nat16 = 0;
              var incr_draw : Nat16 = 0;
              var score = null;
            };

            if (match.is_ranked) {
              if (winner == "white") {
                white_player_data.incr_win := 1;
                black_player_data.incr_lost := 1;
              } else if (winner == "black") {
                white_player_data.incr_lost := 1;
                black_player_data.incr_win := 1;
              } else if (winner == "draw") {
                white_player_data.incr_draw := 1;
                black_player_data.incr_draw := 1;
              };
            };



            let white_player_updated = white_player_object.update({
              username = null;
              country = null;
              fullname = null;
              photo = null;
              is_banned = null;
              incr_win = white_player_data.incr_win;
              incr_lost = white_player_data.incr_lost;
              incr_draw = white_player_data.incr_draw;
              score = white_player_data.score;
            });
            let black_player_updated = black_player_object.update({
              username = null;
              country = null;
              fullname = null;
              photo = null;
              is_banned = null;
              incr_win = black_player_data.incr_win;
              incr_lost = black_player_data.incr_lost;
              incr_draw = black_player_data.incr_draw;
              score = black_player_data.score;
            });

   

            switch (white_player_updated, black_player_updated) {
              case (#err(white_player_err), #err(black_player_err)) {
                Debug.trap("ERROR: " # white_player_err # " : " # black_player_err);
              };
              case _ {
                new_match;
              };
            };

          };
          case (#err(text), _, _) {
            Debug.trap("Release error " # text);
          };
          case (#ok(new_match), _, _) {
            Debug.trap("Release error");
          };
        };

      };
      case null {
        Debug.trap("Release error: match not found");
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

    let random_value = Random.random_nat8();

    Debug.print("Random Value:" # Nat8.toText(random_value));

    var white_player = player_a;
    var black_player = player_b;

    if (random_value % 2 == 0) {
      white_player := player_b;
      black_player := player_a;
    };

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
      // timer = timer;
      last_move = now;
    };

    Map.add<Nat64, Types.Match>(matchs, Nat64.compare, id, match);

    switch (Map.get<Principal, Bool>(on_match, Principal.compare, player_a)) {
      case null {
        Map.add<Principal, Bool>(on_match, Principal.compare, player_a, true);
      };
      case (_) {
        ignore Map.replace<Principal, Bool>(on_match, Principal.compare, player_a, true);
      };
    };

    unfinished_matchs := Array.append(unfinished_matchs, [id]);

    #ok(match);
  };

  public func initialize(_owner : Principal, _chess_engine_principal : Principal) {
    assert not initialized;
    Debug.print("Init" # Principal.toText(_owner));
    owner := _owner;
    chess_engine_principal := _chess_engine_principal;
    initialized := true;
  };

  public shared ({ caller }) func change_initial_fen(new_initial_fen : Text) {
    assert Principal.equal(caller, owner) or Principal.toText(caller) == Principal.toText(owner);

    initial_fen := new_initial_fen;
  };

  public shared ({ caller }) func invite_match(friend_principal : Principal) : async () {
    switch (Map.get<Principal, Principal>(invite_rooms, Principal.compare, caller)) {
      case null {
        Map.add<Principal, Principal>(invite_rooms, Principal.compare, caller, friend_principal);
      };
      case (_) {
        ignore Map.replace<Principal, Principal>(invite_rooms, Principal.compare, caller, friend_principal);
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

  private func _make_move(player : Principal, match_id : Nat64, from_position : Text, to_position : Text, promotion : ?Text) : async Result.Result<Types.Match, Text> {
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
    let now = Nat64.fromIntWrap(Time.now());

    switch (match_object.get(), position, player) {
      case (_, #err(text), _) {
        #err(text);
      };
      case (?match, #ok(from_position_int, to_position_int), player) {
        switch (match.is_white_turn, match.winner, player == match.white_player, player == match.black_player) {
          case (_, "ongoing", false, false) {
            return #err("Forbidden");
          };
          case (true, "ongoing", false, _) {
            return #err("Forbidden");
          };
          case (true, "ongoing", _, true) {
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

        let moves = Array.append<Types.Move>(match.moves, [{ fen = match.fen; time = now }]);

        let updated_match = match_object.update({
          fen = ?result.fen;
          is_white_turn = ?(not match.is_white_turn);
          moves = ?moves;
          winner = null;
          last_move = ?now;
        });

        let status = result.status;
        let turn = status / 10;
        let game_status = status % 10;

        switch (game_status, turn) {
          case (1, _) {
            #ok(release_match(match_id, "draw"));
          };
          case (2, 1) {
            #ok(release_match(match_id, "black"));
          };
          case (2, 2) {
            #ok(release_match(match_id, "white"));
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

  public shared ({ caller }) func make_move(match_id : Nat64, from_position : Text, to_position : Text, promotion : ?Text) : async Result.Result<Types.Match, Text> {
    await _make_move(caller, match_id, from_position, to_position, promotion);
  };

  public shared ({ caller }) func cancel_match_room() : async () {
    Map.remove<Principal, Bool>(rooms, Principal.compare, caller);
  };

  public query func get_match(match_id : Nat64) : async (Result.Result<Types.MatchResult, Text>) {
    let match = Match.Match(matchs, match_id).get();

    switch (match) {
      case (?match) {
        let white_player_user = User.User(users, match.white_player).get();
        let black_player_user = User.User(users, match.black_player).get();

        switch (white_player_user, black_player_user) {
          case (?white_player_user, ?black_player_user) {

            let result : Types.MatchResult = {
              white_player = white_player_user;
              black_player = black_player_user;
              id = match.id;
              moves = match.moves;
              time = match.time;
              winner = match.winner;
              is_ranked = match.is_ranked;
            };
            #ok(result);

          };
          case _ {
            #err("user not found");
          };
        };

      };
      case null {
        #err("Not found");
      };
    };
  };

  public query func get_messages() : async ([Types.WebsocketMessageQueue]) {
    Message.get_messages(messages);
  };

  ignore Timer.recurringTimer<system>(#seconds 10, cronjob) // eksekusi cronjob;
};
