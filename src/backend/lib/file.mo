import Blob "mo:base/Blob";
import Option "mo:base/Option";
import Debug "mo:base/Debug";
import Map "mo:core/Map";
import Types "types";
import Sha256 "mo:sha2/Sha256";

module {
  public func get(files : Map.Map<Blob, Types.File>, hash : Blob) : ?Types.File {
    Map.get<Blob, Types.File>(files, Blob.compare, hash);
  };

  public func insert(files : Map.Map<Blob, Types.File>, filename : Text, data : Blob) : Blob {
    if (data.size() >= 524288) {
      Debug.trap("File too large");
    };

    let hash = Sha256.fromBlob(#sha256, data);
    let file = get(files, hash);

    if (not Option.isNull(file)) {
      Map.add<Blob, Types.File>(
        files,
        Blob.compare,
        hash,
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
