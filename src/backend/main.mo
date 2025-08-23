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
import Text "mo:core/Text";
import Option "mo:base/Option";
import Types "lib/types";
import Helpers "lib/helpers";
import Match "lib/match";
import RandomCustom "lib/random";
import User "lib/user";
import Hex "lib/hex";
import File "lib/file";
import Random "mo:base/Random";
import Nat "mo:base/Nat";
import Country "lib/country";
// import Json "mo:json";

persistent actor {
  // STORAGES
  let users = Map.empty<Text, Types.User>();
  let matchs = Map.empty<Nat64, Types.Match>();
  let files = Map.empty<Text, Types.File>();
  let usernames = Map.empty<Text, Principal>();
  let friends : Types.Friends = Map.empty();
  let histories : Map.Map<Principal, [Nat64]> = Map.empty();

  var unfinished_matchs : [Nat64] = [];
  var match_count : Nat64 = 1;

  var initial_fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
  var owner = Principal.fromBlob(Blob.fromArray([]));
  var initialized = false;
  var chess_engine_principal = Principal.fromBlob(Blob.fromArray([]));

  transient let messages = Buffer.Buffer<Types.WebsocketMessageQueue>(0);
  transient let rooms = Map.empty<Principal, Bool>();
  transient let invite_rooms = Map.empty<Principal, Principal>();
  transient let on_match = Map.empty<Principal, Nat64>();
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

  private func only_owner(caller : Principal) {
    assert Principal.equal(caller, owner) or Principal.toText(caller) == Principal.toText(owner);
  };

  private func get_or_create_user(user_principal : Principal) : Types.User {
    let user = Map.get<Text, Types.User>(users, Text.compare, Principal.toText(user_principal));

    switch (user) {
      case null {
        let user : Types.User = {
          id = Principal.toText(user_principal);
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

        return user;
      };
      case (?user) {
        return user;
      };
    };
  };

  private func can_join_room(user_principal : Principal) : Bool {
    let user = get_or_create_user(user_principal);
    let is_anonymous = Principal.isAnonymous(user_principal);

    let is_banned = user.is_banned;

    let on_match_exists = switch (Map.get<Principal, Nat64>(on_match, Principal.compare, user_principal)) {
      case null {
        false;
      };
      case (_) {
        true;
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
        Map.remove<Principal, Nat64>(on_match, Principal.compare, match.white_player);
        Map.remove<Principal, Nat64>(on_match, Principal.compare, match.black_player);

        let new_match = match_object.update({
          moves = null;
          is_white_turn = null;
          winner = ?winner;
          fen = null;
          last_move = null;
        });

        let white_player_object = User.User(users, friends, match.white_player);
        let black_player_object = User.User(users, friends, match.black_player);

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
                let payload : Types.MatchFinishedMessage = {
                  winner = winner;
                };

                Message.push_message(
                  messages,
                  match.white_player,
                  "match_finished",
                  payload,
                );

                Message.push_message(
                  messages,
                  match.black_player,
                  "match_finished",
                  payload,
                );

                var white_player_histories = Option.get(
                  Map.get<Principal, [Nat64]>(histories, Principal.compare, match.white_player),
                  [],
                );
                var black_player_histories = Option.get(
                  Map.get<Principal, [Nat64]>(histories, Principal.compare, match.black_player),
                  [],
                );

                white_player_histories := Array.append(white_player_histories, [match_id]);
                black_player_histories := Array.append(black_player_histories, [match_id]);

                if (Array.size(white_player_histories) == 1) {
                  Map.add<Principal, [Nat64]>(histories, Principal.compare, match.white_player, white_player_histories);
                } else {
                  ignore Map.replace<Principal, [Nat64]>(histories, Principal.compare, match.white_player, white_player_histories);
                };

                if (Array.size(black_player_histories) == 1) {
                  Map.add<Principal, [Nat64]>(histories, Principal.compare, match.black_player, black_player_histories);
                } else {
                  ignore Map.replace<Principal, [Nat64]>(histories, Principal.compare, match.black_player, black_player_histories);
                };

                return new_match;
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

    let random_value = RandomCustom.random_nat8();

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

    switch (Map.get<Principal, Nat64>(on_match, Principal.compare, player_a)) {
      case null {
        Map.add<Principal, Nat64>(on_match, Principal.compare, player_a, match.id);
      };
      case (_) {
        // ignore Map.replace<Principal, Nat64>(on_match, Principal.compare, player_a, match.id);
        Debug.trap("Player A cant create match");
      };
    };

    switch (Map.get<Principal, Nat64>(on_match, Principal.compare, player_b)) {
      case null {
        Map.add<Principal, Nat64>(on_match, Principal.compare, player_b, match.id);
      };
      case (_) {
        // ignore Map.replace<Principal, Nat64>(on_match, Principal.compare, player_a, match.id);
        Debug.trap("Player B cant create match");
      };
    };

    unfinished_matchs := Array.append(unfinished_matchs, [id]);

    let payload : Types.MatchCreatedMessage = {
      black_player = black_player;
      white_player = white_player;
      fen = match.fen;
      match_id = id;
    };

    Message.push_message(
      messages,
      player_a,
      "match_created",
      payload,
    );

    Message.push_message(
      messages,
      player_b,
      "match_created",
      payload,
    );

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
    only_owner(caller);
    initial_fen := new_initial_fen;
  };

  public shared ({ caller }) func invite_match(friend_principal : Principal) : async (
    Result.Result<Bool, Text>
  ) {
    let user_object = User.User(users, friends, caller);

    if (not user_object.has_friendship(friend_principal)) {
      return #err("not yet friends");
    };

    switch (Map.get<Principal, Principal>(invite_rooms, Principal.compare, caller)) {
      case null {
        Map.add<Principal, Principal>(invite_rooms, Principal.compare, caller, friend_principal);
      };
      case (_) {
        ignore Map.replace<Principal, Principal>(invite_rooms, Principal.compare, caller, friend_principal);
      };
    };

    return #ok(true);
  };

  public shared ({ caller }) func accept_match(friend_principal : Principal) : async Result.Result<Types.Match, Text> {
    let user = get_or_create_user(caller);

    if (user.is_banned) {
      return #err("You has been banned");
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
          case (true, "ongoing", true, false) {

          };
          case (false, "ongoing", false, true) {

          };
          case (_, "ongoing", _, _) {
            return #err("Forbidden");
          };
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

        let payload : Types.MoveCreatedMessage = {
          color = if (match.is_white_turn) "white" else "black";
          fen = result.fen;
          from_position = from_position;
          to_position = to_position;
          promotion = promotion;
        };

        Message.push_message(
          messages,
          match.white_player,
          "move_created",
          payload,
        );

        Message.push_message(
          messages,
          match.black_player,
          "move_created",
          payload,
        );

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

  public shared ({ caller }) func resign() : async (Result.Result<Bool, Text>) {
    let match = await get_active_match(caller);

    switch (match) {
      case (#err(text)) {
        #err(text);
      };
      case (#ok(match)) {
        let winner = if (match.white_player == caller) "black" else "white";
        ignore release_match(match.id, winner);
        #ok(true);
      };
    };
  };

  public query func get_active_match(user_principal : Principal) : async (Result.Result<Types.MatchResultHistory, Text>) {
    let match_id = Map.get<Principal, Nat64>(on_match, Principal.compare, user_principal);

    switch (match_id) {
      case (?match_id) {
        let match = Match.Match(matchs, match_id).get();

        switch (match) {
          case (?match) {
            return #ok(match);
          };
          case null {
            return #err("No active match found");

          };
        };
      };
      case null {
        return #err("No active match found");
      };
    };
  };

  public query func get_user(user_id : Principal) : async (Result.Result<Types.User, Text>) {
    let user = User.User(users, friends, user_id).get();

    switch (user) {
      case (?user) {
        #ok(user);
      };
      case null {
        #err("User not found");
      };
    };
  };

  public query func get_file(file_id_hex : Text) : async (Result.Result<Types.File, Text>) {
    let file = File.get(files, file_id_hex);
    switch (file) {
      case (?file) {
        return #ok(file);
      };
      case null {
        #err("file not found");
      };
    };
  };

  public query func get_match(match_id : Nat64) : async (Result.Result<Types.MatchResult, Text>) {
    let match = Match.Match(matchs, match_id).get();

    switch (match) {
      case (?match) {
        let white_player_user = User.User(users, friends, match.white_player).get();
        let black_player_user = User.User(users, friends, match.black_player).get();

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

  public query func get_histories(user_principal : Principal, start : Nat, max : Nat) : async (
    Result.Result<[Types.MatchResultHistory], Text>
  ) {
    let user_histories = Option.get(
      Map.get<Principal, [Nat64]>(histories, Principal.compare, user_principal),
      [],
    );

    var results : [Types.MatchResultHistory] = [];
    var i = start;

    Debug.print(Nat.toText(Array.size(user_histories)) # "WEH EHEHEH");

    label l while (true) {
      if (i >= Array.size(user_histories)) {
        break l;
      };

      let match_id = user_histories.get(i);
      Debug.print(Nat64.toText(match_id) # " KASEPKAASEP");
      let match_object = Match.Match(matchs, match_id);
      i += 1;

      switch (match_object.get()) {
        case (?match) {
          let history : Types.MatchResultHistory = {
            match with
            white_player = match.white_player;
            black_player = match.black_player;
          };

          results := Array.append(results, [history]);
        };
        case null {};
      };

      if (Array.size(results) >= max) {
        break l;
      };
    };

    return #ok(results);
  };

  public shared ({ caller }) func edit_user(new_user : User.EditUser) : async (Result.Result<Bool, Text>) {
    ignore get_or_create_user(caller);

    let user_object = User.User(users, friends, caller);
    var user_updated : User.UpdatedUser = {
      country = new_user.country;
      fullname = new_user.fullname;
      username = new_user.username;
      is_banned = null;
      incr_lost = 0;
      incr_win = 0;
      incr_draw = 0;
      score = null;
      photo = null;
    };

    func prechange_username(username : Text) : async () {
      if (Option.isSome(Map.get(users, Text.compare, username))) {
        Debug.trap("Username exists");
      };

      let user = await get_user(caller);

      switch (user) {
        case (#ok(user)) {

          switch (user.username) {
            case (?current_username) {
              Map.remove<Text, Principal>(usernames, Text.compare, current_username);
            };
            case null {};
          };

        };
        case (#err(text)) {
          Debug.trap(text);
        };
      };
    };

    func prechange_photo(photo : { extension : Text; data : Blob }) : async (Blob) {
      switch (photo.extension) {
        case "jpg" {};
        case "png" {};
        case "jpeg" {};
        case _ {
          Debug.trap("Extension not permitted");
        };
      };

      if (photo.data.size() >= 524288) {
        Debug.trap("File too big");
      };

      let random_blob = await Random.blob();
      let random_string = Hex.encode(random_blob);

      let file_id = File.insert(files, random_string # "." # photo.extension, photo.data);

      return file_id;
    };

    if (Option.isSome(new_user.country)) {
      if (
        not Country.is_country_code_valid(
          Option.get(new_user.country, "")
        )
      ) {
        return #err("Country code invalid");
      }

    };

    switch (user_object.get(), new_user.username, new_user.photo) {
      case (null, _, _) {
        #err("user not registered");
      };
      case (_, null, null) {
        ignore user_object.update(user_updated);
        #ok(true);
      };
      case (_, ?new_username, null) {
        await prechange_username(new_username);
        ignore user_object.update(user_updated);
        #ok(true);
      };
      case (_, null, ?new_photo) {
        let file_id = await prechange_photo({
          extension = new_photo.extension;
          data = new_photo.data;
        });

        user_updated := { user_updated with photo = ?file_id };
        ignore user_object.update(user_updated);
        #ok(true);
      };
      case (_, ?new_username, ?new_photo) {
        let file_id = await prechange_photo({
          extension = new_photo.extension;
          data = new_photo.data;
        });

        user_updated := { user_updated with photo = ?file_id };

        await prechange_username(new_username);
        ignore user_object.update(user_updated);
        #ok(true);
      };
    };
  };

  public shared ({ caller }) func register() : async () {
    ignore get_or_create_user(caller);
  };

  public shared ({ caller }) func send_friendship(to : Principal) : async (Result.Result<Bool, Text>) {
    let user_object = User.User(users, friends, caller);

    switch (user_object.get()) {
      case (?_user) {
        let payload : Types.SendFriendshipMessage = {
          from = caller;
          to = to;
        };

        Message.push_message(
          messages,
          to,
          "incoming_friendship",
          payload,
        );

        return user_object.send_friendship(to);
      };
      case null {
        return #err("User not found");
      };
    };

  };

  public shared ({ caller }) func accept_friendship(from : Principal) : async (Result.Result<Bool, Text>) {
    let user_object = User.User(users, friends, caller);

    switch (user_object.get()) {
      case (?_user) {
        let payload : Types.AcceptFriendshipMessage = {
          from = caller;
        };

        Message.push_message(
          messages,
          from,
          "accepted_friendship",
          payload,
        );
        return user_object.accept_friendship(from);
      };
      case null {
        return #err("User not found");
      };
    };
  };

  public shared ({ caller }) func reject_friendship(from : Principal) : async (Result.Result<Bool, Text>) {
    let user_object = User.User(users, friends, caller);

    switch (user_object.get()) {
      case (?_user) {
        let payload : Types.RejectFriendshipMessage = {
          from = caller;
        };

        Message.push_message(
          messages,
          from,
          "rejected_friendship",
          payload,
        );
        return user_object.reject_friendship(from);
      };
      case null {
        return #err("User not found");
      };
    };
  };

  public query func get_friends(user_principal : Principal, incoming : Bool) : async (Result.Result<[Types.User], Text>) {
    let user_object = User.User(users, friends, user_principal);

    switch (user_object.get()) {
      case (?_user) {
        return user_object.get_friends(incoming);
      };
      case null {
        return #err("User not found");
      };
    };
  };

  public shared ({ caller }) func pop_messages() : async ([Types.WebsocketMessageQueue]) {
    only_owner(caller);
    Message.pop_messages(messages);
  };

  ignore Timer.recurringTimer<system>(#seconds 10, cronjob) // eksekusi cronjob;
};
