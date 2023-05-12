#import "Basic";
#import "File";
#import "String";

GetLine :: (s : *u8, offset : u32) -> string, u32 {
    result : string;
    s += offset;
    c := s;
    while <<c != #char "\r" && <<c != #char "\n" {        
        c += 1;
    }
    result.count = c - s;
    result.data = cast(*u8)alloc(result.count);
    memcpy(result.data, s, result.count);

    // advance to next char that is not '\n' or '\r'.
    charsRead := result.count;
    while <<c == #char "\r" || <<c == #char "\n" {
        c += 1;
        charsRead += 1;
    }

    return result, cast(u32)charsRead;
}

LoadMAP :: (mapFile : string) {
    mapFileData := read_entire_file(mapFile);
    
    line, charsRead := GetLine(mapFileData.data, 0);
    print("%\n", line);

    totalCharsRead := charsRead;
    print("charsRead: %\n", charsRead);
    print("totalCharsRead: %\n", totalCharsRead);
    print("mapFileData.count: %\n", mapFileData.count);
    while totalCharsRead < mapFileData.count {        
        line, charsRead = GetLine(mapFileData.data, totalCharsRead);
        print("%\n", line);
        totalCharsRead += charsRead;
    }

    // line, pos = GetLine(mapFileData.data, pos);
    // print(line);

    
}
