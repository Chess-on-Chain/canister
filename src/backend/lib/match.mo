import Map "mo:core/Map";
import Types "types";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
// import User "user";

module {

  type UpdatedMatch = {
    moves : ?[Types.Move];
    is_white_turn : ?Bool;
    winner : ?Text;
    fen : ?Text;
    last_move : ?Nat64;
  };

  // type MapMatch = Map.Map<Nat64, Types.Match>;

  public func insert(matchs : Map.Map<Nat64, Types.Match>, id : Nat64, match : Types.Match) {
    Map.add<Nat64, Types.Match>(matchs, Nat64.compare, id, match);
  };

  public class Match(matchs : Map.Map<Nat64, Types.Match>, match_id : Nat64) {
    public func get() : ?Types.Match {
      Map.get<Nat64, Types.Match>(matchs, Nat64.compare, match_id);
    };

    // public func get_white_player() : ?Types.User {
    //   let match = get();

    //   switch (match) {
    //     case (?match) {
    //       User.User(, match.white_player).get()
    //     };
    //     case null {
    //       return null;
    //     }
    //   };
    // };

    public func update(new_match : UpdatedMatch) : Result.Result<Types.Match, Text> {
      let old_match = get();

      // let now = Nat64.fromIntWrap(Time.now());

      switch (old_match) {
        case (?old_match) {
          Debug.print("Update match id: " # Nat64.toText(old_match.id));
          let new_moves = Option.get<[Types.Move]>(new_match.moves, old_match.moves);
          let new_is_white_turn = Option.get<Bool>(new_match.is_white_turn, old_match.is_white_turn);
          let new_winner = Option.get<Text>(new_match.winner, old_match.winner);
          // let new_timer = Option.get<Timer.TimerId>(new_match.timer, old_match.timer);
          let new_fen = Option.get<Text>(new_match.fen, old_match.fen);
          let new_last_move = Option.get<Nat64>(new_match.last_move, old_match.last_move);

          let match : Types.Match = {
            id = old_match.id;
            white_player = old_match.white_player;
            black_player = old_match.black_player;
            time = old_match.time;
            is_ranked = old_match.is_ranked;
            moves = new_moves;
            is_white_turn = new_is_white_turn;
            winner = new_winner;
            last_move = new_last_move;
            fen = new_fen;
          };

          let _ = Map.replace<Nat64, Types.Match>(matchs, Nat64.compare, match_id, match);

          #ok(match);
        };
        case (_) {
          #err("Match not found");
        };
      }

    };
  };
};
