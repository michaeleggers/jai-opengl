#import "Basic";
#import "File";
#import "String";

charsRead  : u32;
lineNumber : u32 = 1;
tokens     : [..] Token;
brushes    : [..] Brush;

TokenType :: enum u32 {
    BRACE_OPEN;
    BRACE_CLOSE;
    NUMBER;
    STRING;
    COMMENT;
    COMMA;
    EOF;
    NONE;
}

Token :: struct { // TODO: Can we make this polymorphic, or make a union, like in C?
    type : TokenType;
    number : float;
    name : string;
}

Brush :: struct {
    xPos, yPos, zPos : float;
    texture : string;
    height : float;
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
    while <<s.data != #char " " && <<s.data != #char "," { // @FIXME: The ',' here is weird!
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

GetNextToken :: (s : *string) -> TokenType {
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

    token : TokenType;
    if <<s.data == #char "{" {        
        s.data += 1; charsRead +=1;
        token = .BRACE_OPEN;
    } else if <<s.data == #char "}" {        
        s.data += 1; charsRead +=1;
        token = .BRACE_CLOSE;        
    } else if <<s.data >= #char "0" && <<s.data <= #char "9" || <<s.data == #char "-" {
        token = .NUMBER;        
    } else if <<s.data == #char "\"" {        
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

// Like GetNextToken but does not advance cursor, except for newlines and comments
PeekToken :: (s : *string) -> TokenType {
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

    token : TokenType;
    if <<s.data == #char "{" {        
        token = .BRACE_OPEN;
    } else if <<s.data == #char "}" {                
        token = .BRACE_CLOSE;        
    } else if <<s.data >= #char "0" && <<s.data <= #char "9" || <<s.data == #char "-" {
        token = .NUMBER;        
    } else if <<s.data == #char "\"" {        
        token = .STRING;    
    } else if <<s.data == #char "," {
        token = .COMMA;        
    } else {
        token = .NONE;
    }
    print("%\n", token);

    return token;
}

Match :: (s : *string, expectedToken : TokenType) -> bool {
    token := GetNextToken(s);
    assert(token == expectedToken, "Expected % but got % in Line: %\n", expectedToken, token, lineNumber);
    return token == expectedToken;
}

ParseBrush :: (s : *string) {    
    Match(s, .NUMBER);  // TODO: Redundant match, see: ParseBrushOrEntity
    xPos := ParseNumber(s); Match(s, .COMMA);
    Match(s, .NUMBER); 
    yPos := ParseNumber(s); Match(s, .COMMA);
    Match(s, .NUMBER); 
    zPos := ParseNumber(s); Match(s, .COMMA);
    Match(s, .STRING); 
    texture := ParseString(s); Match(s, .COMMA);
    Match(s, .NUMBER); 
    height := ParseNumber(s);
    Match(s, .BRACE_CLOSE);

    brush := Brush.{
        xPos = xPos.number, yPos = yPos.number, zPos = zPos.number,
        texture = texture.name,
        height = height.number
    };
    array_add(*brushes, brush);    
}

ParseEntity :: (s : *string) {
    Match(s, .STRING); // TODO: Redundant match, see: ParseBrushOrEntity
    while GetNextToken(s) != .BRACE_CLOSE {
        key := ParseString(s);
        if PeekToken(s) == .STRING {
            value := ParseString(s);            
        } else if PeekToken(s) == .NUMBER {
            x := ParseNumber(s); Match(s, .COMMA); 
            Match(s, .NUMBER);
            y := ParseNumber(s); Match(s, .COMMA);
            Match(s, .NUMBER);
            z := ParseNumber(s);
        }
    }
}

ParseBrushOrEntity :: (s : *string) {
    if      PeekToken(s) == .NUMBER ParseBrush(s);
    else if PeekToken(s) == .STRING ParseEntity(s);
}

ParseNumber :: (s : *string) -> Token {
    numberString := <<s;    
    c := s.data;

    if <<s.data == #char "-" { // '-' is only allowed at the beginning of a number!
        s.data += 1; charsRead += 1;
    }
    while <<s.data >= #char "0" && <<s.data <= #char "9" || <<s.data == #char "." {
        s.data += 1; charsRead +=1;
    }
    numberString.count = s.data - c;

    result := Token.{type = .NUMBER};
    result.number = string_to_float(numberString);    

    return result;
}

ParseString :: (s : *string) -> Token {    
    s.data += 1; charsRead += 1; // advance over opening "
    parsedString := <<s;
    c := s.data;
    // while <<s.data >= #char "a" && <<s.data <= #char "z"
    //    || <<s.data >= #char "0" && <<s.data <= #char "9" {
    //     s.data += 1; charsRead +=1;
    // }
    while <<s.data != #char "\"" {
        s.data += 1; charsRead += 1;
    }
    parsedString.count = s.data - c;
    s.data += 1; charsRead += 1; // advance over closing "

    result := Token.{type = .STRING};
    result.name = parsedString;
    
    return result;
}

LoadMapFile :: (mapFile : string) -> [] Brush{

    mapFileData := read_entire_file(mapFile);
    
    token := GetNextToken(*mapFileData);    
    while token != .EOF {        
        if token == {
            case .BRACE_OPEN; ParseBrushOrEntity(*mapFileData);
            case .NONE;       
        }
        token = GetNextToken(*mapFileData);
    }

    print("# Lines processed: %\n", lineNumber);
    print("# Brushes parsed: %\n", brushes.count);
    print("Brushes:\n");
    for brushes {
        print("%\n", it);
    }
    
    return brushes;
}
