import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";

module {
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
    photo : ?File;
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
    body : Text;
  };

  public module Http {
    public type HeaderField = (Text, Text);

    public type HttpRequest = {
      method : Text;
      url : Text;
      headers : [HeaderField];
      body : Blob;
      certificate_version : ?Nat16;
    };

    public type HttpUpdateRequest = {
      method : Text;
      url : Text;
      headers : [HeaderField];
      body : Blob;
    };

    public type HttpResponse = {
      status_code : Nat16;
      headers : [HeaderField];
      body : Blob;
      upgrade : ?Bool;
      streaming_strategy : ?StreamingStrategy;
    };

    public type StreamingToken = Text;

    public type StreamingCallbackHttpResponse = {
      body : Blob;
      token : ?StreamingToken;
    };

    public type StreamingStrategy = {
      #Callback : {
        callback : shared query (StreamingToken) -> async (?StreamingCallbackHttpResponse);
        token : StreamingToken;
      };
    };
  };
};
