#import "Basic";
#import "File";
#import "String";

charsRead  : u32;
lineNumber : u32;

Token :: enum u32 {
    BRACE_OPEN;
    BRACE_CLOSE;
    NUMBER;
    STRING;
    COMMENT;
    COMMA;
    EOF;
    NONE;
}

GetLine :: (s : *u8, offset : u32) -> string, u32 {
    result : string;
    
    s += offset;
    c := s;
    while <<c != #char "\r" && <<c != #char "\n" {        
        c += 1;
    }
    
    result.data = s;
    result.count = c - s;

    // advance to next char that is not '\n' or '\r'.
    charsRead := result.count;
    while <<c == #char "\r" || <<c == #char "\n" {
        c += 1;
        charsRead += 1;
    }

    return result, cast(u32)charsRead;
}

AdvanceToNextNonWhitespace :: (s : *string) {
    while <<s.data == #char " " {
        s.data += 1; charsRead +=1;
    }
}

AdvanceToNextWhitespace :: (s : *string) {
    while <<s.data != #char " " && <<s.data != #char "," { // FIXME: The ',' here is weird!
        s.data += 1; charsRead += 1;
    }
}

AdvanceToNextLineBreak :: (s : *string) {
    while <<s.data != #char "\r" && <<s.data != #char "\n" {
        s.data += 1; charsRead +=1;
    }
}

SkipLineBreak :: (s : *string) -> bool {
    if begins_with(<<s, "\r") {
        s.data += 1; charsRead += 1;
        if begins_with(<<s, "\n") {
            s.data += 1; charsRead += 1;
        }
        lineNumber += 1;
        return true;
    }

    return false;
}

IsComment :: (s : *string) -> bool {
    if begins_with(<<s, "#") {
        return true;
    }

    return false;
}

GetNextToken :: (s : *string) -> Token {
    AdvanceToNextNonWhitespace(s);
    while SkipLineBreak(s) {
        AdvanceToNextNonWhitespace(s);
    }
    while (IsComment(s)) {
        AdvanceToNextLineBreak(s);
        while SkipLineBreak(s) {
            AdvanceToNextNonWhitespace(s);            
        }
    }

    if charsRead == s.count { // End of file reached
        return .EOF;
    }

    token : Token;
    if <<s.data == #char "{" {        
        s.data += 1; charsRead +=1;
        token = .BRACE_OPEN;
    } else if <<s.data == #char "}" {        
        s.data += 1; charsRead +=1;
        token = .BRACE_CLOSE;        
    } else if <<s.data >= #char "0" && <<s.data <= #char "9" {
        token = .NUMBER;        
    } else if <<s.data >= #char "a" && <<s.data <= #char "z" {        
        token = .STRING;    
    } else if <<s.data == #char "," {
        s.data += 1; charsRead +=1;
        token = .COMMA;        
    } else {
        token = .NONE;
    }
    print("%\n", token);

    return token;
}

Match :: (s : *string, expectedToken : Token) -> bool {
    token := GetNextToken(s);
    assert(token == expectedToken, "Expected % but got %!\n", expectedToken, token);
    return token == expectedToken;
}

ParseBrush :: (s : *string) {
    Match(s, .NUMBER); ParseNumber(s); Match(s, .COMMA);
    Match(s, .NUMBER); ParseNumber(s); Match(s, .COMMA);
    Match(s, .NUMBER); ParseNumber(s); Match(s, .COMMA);
    Match(s, .STRING); ParseString(s); Match(s, .COMMA);
    Match(s, .NUMBER); ParseNumber(s);
    Match(s, .BRACE_CLOSE);
}

ParseNumber :: (s : *string) -> float {
    numberString := <<s;    
    c := s.data;
    while <<s.data >= #char "0" && <<s.data <= #char "9" || <<s.data == #char "." {
        s.data += 1; charsRead +=1;
    }
    numberString.count = s.data - c;

    result := string_to_float(numberString);    

    return result;
}

ParseString :: (s : *string) -> string {    
    result := <<s;
    c := s.data;
    // while <<s.data >= #char "a" && <<s.data <= #char "z"
    //    || <<s.data >= #char "0" && <<s.data <= #char "9" {
    //     s.data += 1; charsRead +=1;
    // }
    AdvanceToNextWhitespace(s);
    result.count = s.data - c;
    print("%\n", result);
    
    return result;
}

LoadMapFile :: (mapFile : string) {

    mapFileData := read_entire_file(mapFile);
    
    token := GetNextToken(*mapFileData);    
    while token != .EOF {        
        if token == {
            case .BRACE_OPEN; ParseBrush(*mapFileData);
            case .NONE;       
        }
        token = GetNextToken(*mapFileData);
    }

    print("# Lines processed: %\n", lineNumber);
    
    // line, charsRead := GetLine(mapFileData.data, 0);
    // print("First line read: %\n", line.count);
    // totalCharsRead := charsRead;
    // print("charsRead: %\n", charsRead);
    // print("totalCharsRead: %\n", totalCharsRead);
    // print("mapFileData.count: %\n", mapFileData.count);
    // while totalCharsRead < mapFileData.count {        
    //     line, charsRead = GetLine(mapFileData.data, totalCharsRead);
    //     totalCharsRead += charsRead;
    //     line = trim_left(line);

    //     // Do not care about comments
    //     if begins_with(line, "#") continue;
    //     print("Processing: %\n", line);
    // }
    
}
