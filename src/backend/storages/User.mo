import Map "mo:core/Map";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Types "./../lib/types";

module {
    let users = Map.empty<Text, Nat>();
}