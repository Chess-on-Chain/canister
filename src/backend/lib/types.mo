import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Map "mo:core/Map";

module {
  public type FriendsKey = Text;
  public type FriendsValue = Text;
  public type Friends = Map.Map<FriendsKey, FriendsValue>;

  // public type HistoryMatch = ;
  
  public type Move = {
    fen : Text;
    time : Nat64;
  };

  public type File = {
    filename : Text;
    data : Blob;
    hash : Blob;
  };

  public type User = {
    id : Text;
    win : Nat16;
    lost : Nat16;
    draw : Nat16;
    username : ?Text;
    fullname : Text;
    score : Nat16;
    is_banned : Bool;
    country : ?Text;
    photo : ?Blob;
  };

  public type Match = {
    id : Nat64;
    white_player : Principal;
    black_player : Principal;
    fen : Text;
    moves : [Move];
    is_white_turn : Bool;
    winner : Text; // Could use variant for 'white', 'black', etc.
    is_ranked : Bool;
    time : Nat64;
    last_move : Nat64;
  };

  public type MatchCreated = {
    #match : Match;
    #text : Text;
  };

  public type MatchResult = {
    id : Nat64;
    white_player : User;
    black_player : User;
    moves : [Move];
    winner : Text;
    is_ranked : Bool;
    time : Nat64;
  };

  public type MatchResultHistory = {
    id : Nat64;
    white_player : Principal;
    black_player : Principal;
    moves : [Move];
    winner : Text;
    is_ranked : Bool;
    time : Nat64;
  };

  public type WebsocketMessageQueue = {
    principal : Principal;
    method : Text;
    body : Blob;
  };

  public type SendFriendshipMessage = {
    // incoming_friendship
    from : Principal;
    to : Principal;
  };

  public type AcceptFriendshipMessage = {
    // accepted_friendship
    from : Principal;
  };

  public type RejectFriendshipMessage = {
    // rejected_friendship
    from : Principal;
  };

  public type MatchCreatedMessage = {
    // match_created
    white_player : Principal;
    black_player : Principal;
    match_id : Nat64;
    fen : Text;
  };

  public type MoveCreatedMessage = {
    // move_created
    color : Text;
    from_position : Text;
    to_position : Text;
    promotion : ?Text;
    fen : Text;
  };

  public type MatchFinishedMessage = {
    // match_finished
    winner : Text;
  };

};
