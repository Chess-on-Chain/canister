import Map "mo:core/Map";
import Types "types";
import Option "mo:base/Option";
import Result "mo:base/Result";
import Nat16 "mo:base/Nat16";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Text "mo:core/Text";
import Blob "mo:core/Blob";

module UserModule {
  public type EditUser = {
    username : ?Text;
    fullname : ?Text;
    country : ?Text;
    photo : ?{
      extension : Text;
      data : Blob;
    };
  };

  public type UpdatedUser = {
    username : ?Text;
    fullname : ?Text;
    incr_win : Nat16;
    incr_lost : Nat16;
    incr_draw : Nat16;
    score : ?Nat16;
    is_banned : ?Bool;
    country : ?Text;
    photo : ?Blob;
  };

  public func insert(users : Map.Map<Text, Types.User>, id : Principal, user : Types.User) {
    Map.add<Text, Types.User>(users, Text.compare, Principal.toText(id), user);
  };

  public func get(users : Map.Map<Text, Types.User>, user_id : Principal) : ?Types.User {
    Map.get<Text, Types.User>(users, Text.compare, Principal.toText(user_id));
  };

  public func pair_principal(principalA : Principal, principalB : Principal) : Text {
    let principalAHash = Principal.hash(principalA);
    let principalBHash = Principal.hash(principalB);

    if (principalAHash > principalBHash) {
      return Principal.toText(principalA) # "_" # Principal.toText(principalB);
    } else {
      return Principal.toText(principalB) # "_" # Principal.toText(principalA);
    };
  };

  public class User(
    users : Map.Map<Text, Types.User>,
    friends : Types.Friends,
    user_id : Principal,
  ) {

    public func get() : ?Types.User {
      Map.get<Text, Types.User>(users, Text.compare, Principal.toText(user_id));
    };

    public func has_friendship(with_principal : Principal) : Bool {
      let user = get();

      switch (user) {
        case (?user) {
          let key = pair_principal(Principal.fromText(user.id), with_principal);

          let frienship_status = Option.get(
            Map.get<Types.FriendsKey, Types.FriendsValue>(friends, Text.compare, key),
            "nothing",
          );

          return frienship_status == "friend";
        };
        case _ {
          Debug.trap("User not found");
        };
      };
    };

    public func accept_friendship(from : Principal) : Result.Result<Bool, Text> {
      let user = get();

      switch (user) {
        case (?user) {
          let key = pair_principal(Principal.fromText(user.id), from);

          let frienship_status = Option.get(
            Map.get<Types.FriendsKey, Types.FriendsValue>(friends, Text.compare, key),
            "nothing",
          );

          if (not Text.startsWith(frienship_status, #text("incoming"))) {
            return #err("No request found");
          } else {
            let requester = Text.replace(frienship_status, #text("incoming_from_"), "");

            if (requester == user.id) {
              return #err("Forbidden");
            };

            ignore Map.replace<Types.FriendsKey, Types.FriendsValue>(friends, Text.compare, key, "friend");
            return #ok(true);
          };

        };
        case null {
          #err("User not found");

        };
      };
    };

    public func reject_friendship(from : Principal) : Result.Result<Bool, Text> {
      let user = get();

      switch (user) {
        case (?user) {
          let key = pair_principal(Principal.fromText(user.id), from);

          let frienship_status = Option.get(
            Map.get<Types.FriendsKey, Types.FriendsValue>(friends, Text.compare, key),
            "nothing",
          );

          // if (frienship_status != "incoming") {
          if (not Text.startsWith(frienship_status, #text("incoming"))) {
            return #err("No request found");
          } else {
            Map.remove<Types.FriendsKey, Types.FriendsValue>(friends, Text.compare, key);
            return #ok(true);
          };

        };
        case null {
          #err("User not found");

        };
      };
    };

    public func send_friendship(to : Principal) : Result.Result<Bool, Text> {
      let user = get();

      switch (user) {
        case (?user) {
          let key = pair_principal(Principal.fromText(user.id), to);

          let frienship_status = Option.get(
            Map.get<Types.FriendsKey, Types.FriendsValue>(friends, Text.compare, key),
            "nothing",
          );

          if (frienship_status == "nothing") {
            let value = "incoming_from_" # user.id;
            Map.add<Types.FriendsKey, Types.FriendsValue>(friends, Text.compare, key, value);
          };

          #ok(true);

        };
        case null {
          #err("User not found");

        };
      };
    };

    public func get_friends(incoming : Bool) : Result.Result<[Types.User], Text> {
      let user = get();

      switch (user) {
        case (?user) {
          let status = if (incoming) "incoming" else "friend";
          let entries = Map.entries<Types.FriendsKey, Types.FriendsValue>(friends);
          var results : [Types.User] = [];

          for ((k, v) in entries) {
            if (
              Text.startsWith(v, #text(status)) and
              not Text.endsWith(v, #text(user.id))
            ) {

              let split_principal = Text.split(k, #text("_"));
              let principal_a = split_principal.next();
              let principal_b = split_principal.next();

              if (Text.startsWith(k, #text(user.id))) {

                switch (principal_b) {
                  case (?principal_b) {
                    let friend = UserModule.get(users, Principal.fromText(principal_b));

                    switch (friend) {
                      case (?friend) {
                        results := Array.append<Types.User>(results, [friend]);
                      };
                      case null {};
                    };
                  };
                  case null {

                  };
                }

              } else if (Text.endsWith(k, #text(user.id))) {

                switch (principal_a) {
                  case (?principal_a) {

                    let friend = UserModule.get(users, Principal.fromText(principal_a));

                    switch (friend) {
                      case (?friend) {
                        results := Array.append<Types.User>(results, [friend]);
                      };
                      case null {};
                    };
                  };
                  case null {

                  };
                }

              };
            };
          };

          return #ok(results);
        };
        case null {
          return #err("User not found");

        };
      }

    };

    public func update(new_user : UpdatedUser) : Result.Result<Types.User, Text> {
      let old_user = get();

      switch (old_user) {
        case (?old_user) {
          let new_username : ?Text = if (not Option.isNull(new_user.username)) new_user.username else old_user.username;
          let new_fullname = Option.get<Text>(new_user.fullname, old_user.fullname);
          let new_win = old_user.win + new_user.incr_win;
          let new_lost = old_user.lost + new_user.incr_lost;
          let new_draw = old_user.draw + new_user.incr_draw;
          let new_score = Option.get<Nat16>(new_user.score, old_user.score);
          let new_is_banned = Option.get<Bool>(new_user.is_banned, old_user.is_banned);
          let new_country : ?Text = if (not Option.isNull(new_user.country)) new_user.country else old_user.country;
          let new_photo : ?Blob = if (not Option.isNull(new_user.photo)) new_user.photo else old_user.photo;

          let user : Types.User = {
            id = old_user.id;
            username = new_username;
            fullname = new_fullname;
            win = new_win;
            lost = new_lost;
            draw = new_draw;
            score = new_score;
            is_banned = new_is_banned;
            country = new_country;
            photo = new_photo;
          };

          ignore Map.replace<Text, Types.User>(users, Text.compare, Principal.toText(user_id), user);

          #ok(user);
        };
        case (_) {
          #err("User not found");
        };
      }

    };
  };
};
