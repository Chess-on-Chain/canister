import Blob "mo:base/Blob";
import Option "mo:base/Option";
import Debug "mo:base/Debug";
import Text "mo:base/Text";
import Map "mo:core/Map";
import Types "types";
import Sha256 "mo:sha2/Sha256";
import Hex "hex";

module {
  public func get(files : Map.Map<Text, Types.File>, hash : Text) : ?Types.File {
    Map.get<Text, Types.File>(files, Text.compare, hash);
  };

  public func insert(files : Map.Map<Text, Types.File>, filename : Text, data : Blob) : Blob {
    if (data.size() >= 524288) {
      Debug.trap("File too large");
    };

    let hash = Sha256.fromBlob(#sha256, data);
    let hash_hex = Hex.encode(hash);
    Debug.print(hash_hex);
    let file = get(files, hash_hex);

    if (Option.isNull(file)) {
      Map.add<Text, Types.File>(
        files,
        Text.compare,
        hash_hex,
        {
          filename = filename;
          data = data;
          hash = hash;
        },
      );
    };

    hash;
  };
};
