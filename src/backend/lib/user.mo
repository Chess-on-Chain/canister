import Map "mo:core/Map";
import Types "types";
import Option "mo:base/Option";
import Result "mo:base/Result";
import Nat16 "mo:base/Nat16";
import Principal "mo:base/Principal";

module {

  type UpdatedUser = {
    username : ?Text;
    fullname : ?Text;
    incr_win : Nat16;
    incr_lost : Nat16;
    incr_draw : Nat16;
    score : ?Nat16;
    is_banned : ?Bool;
    country : ?Text;
    photo : ?Types.File;
  };

  public func insert(users : Map.Map<Principal, Types.User>, id : Principal, user : Types.User) {
    Map.add<Principal, Types.User>(users, Principal.compare, id, user);
  };

  public class User(users : Map.Map<Principal, Types.User>, user_id : Principal) {
    public func get() : ?Types.User {
      Map.get<Principal, Types.User>(users, Principal.compare, user_id);
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
          let new_photo : ?Types.File = if (not Option.isNull(new_user.photo)) new_user.photo else old_user.photo;

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

          ignore Map.replace<Principal, Types.User>(users, Principal.compare, user_id, user);

          #ok(user);
        };
        case (_) {
          #err("User not found");
        };
      }

    };
  };
};
