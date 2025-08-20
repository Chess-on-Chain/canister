import Blob "mo:base/Blob";
import Option "mo:base/Option";
import Debug "mo:base/Debug";
import Text "mo:base/Text";
import Map "mo:core/Map";
import Types "types";
import Sha256 "mo:sha2/Sha256";
import Array "mo:base/Array";
import Iter "mo:base/Iter";

module {
  public func encode_file_with_name(filename : Text, fileBytes : Blob) : Blob {
    let nameBytes = Text.encodeUtf8(filename); // Konversi filename ke Blob
    let nameArray = Blob.toArray(nameBytes); // [Nat8]
    if (nameArray.size() > 1024) {
      // Filename terlalu panjang
      assert false; // Atau bisa menggunakan throw jika ingin error handling custom
    };
    // Padding dengan 0 agar pas 1024 byte
    let paddedName = Array.tabulate<Nat8>(
      1024,
      func(i) {
        if (i < nameArray.size()) nameArray[i] else 0;
      },
    );
    // Gabungkan paddedName dan fileBytes
    let resultArray = Array.append<Nat8>(paddedName, Blob.toArray(fileBytes));
    Blob.fromArray(resultArray);
  };

  // Fungsi untuk decode file: mengembalikan (filename, fileBytes)
  public func decode_file_with_name(blob : Blob) : (Text, Blob) {
    let arr = Blob.toArray(blob);
    if (arr.size() < 1024) {
      assert false; // Atau throw error
    };
    // Ambil 1024 byte pertama untuk filename
    let nameBytes = Array.subArray<Nat8>(arr, 0, 1024);
    // Hilangkan padding 0
    var endIdx = 1024;
    label search for (i in Iter.range(0, 1023)) {
      if (nameBytes[1023 - i] != 0) {
        endIdx := 1024 - i;
        break search;
      };
    };
    let trimmedNameBytes = Array.subArray<Nat8>(nameBytes, 0, endIdx);
    let filenameOpt = Text.decodeUtf8(Blob.fromArray(trimmedNameBytes));
    let filename = switch filenameOpt {
      case (?t) t;
      case null {
        Debug.trap("Decode failed");
      }; // atau throw error jika decode gagal
    };
    // Sisanya adalah fileBytes
    let fileBytes = Blob.fromArray(Array.subArray<Nat8>(arr, 1024, arr.size() - 1024));
    (filename, fileBytes);
  };
  public func get_mimetype_from_extension(filename : Text) : ?Text {
    let parts = Text.split(filename, #text ".");

    ignore parts.next();
    let extension = parts.next();

    switch (extension) {
      case (?extension) {
        if (extension == "jpeg" or extension == "jpg") {
          return ?"image/jpeg";
        } else if (extension == "png") {
          return ?"image/png";
        } else {
          return null;
        };
      };
      case _ {
        return null;
      };
    };
  };

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
