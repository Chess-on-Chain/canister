import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Nat8 "mo:base/Nat8";

module {
  public type NextMoveStatusResponse = {
    fen : Text;
    status : Nat8;
  };

  public type ActorCandid = actor {
    next_move_and_status : shared query (Text, Nat8, Nat8, ?Text) -> async (NextMoveStatusResponse);
  };

  private func get_actor(chess_engine_principal : Principal) : ActorCandid {
    actor (Principal.toText(chess_engine_principal)) : ActorCandid;
  };

  public func next_move_and_status(
    chess_engine_principal : Principal,
    fen : Text,
    from_position : Nat8,
    to_position : Nat8,
    promotion : ?Text,
  ) : async (NextMoveStatusResponse) {
    let chess_engine = get_actor(chess_engine_principal);
    await chess_engine.next_move_and_status(fen, from_position, to_position, promotion);
  };
};
