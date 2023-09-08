/*
* Quake MAP parser.
*
* Grammar:
* ----------------------------------------------------------------
* Terminals = {key, value, plane, texture, offset, scale, rotation}
* Non Terminals = {map, entity, property, brush, face}

* map         -> entity *entity
* entity      -> *property *brush
* property    -> key value
* brush       -> *face
* face        -> plane texture-name xOffset yOffset rotation xScale yScale
*
* A plane is defined by 3 vertices.
* A property is always a pair of strings.
*
* For more information, see: https://quakewiki.org/wiki/Quake_Map_Format
*/


#import "Basic";
#import "Math";
#import "File";

#scope_file

g_InputLength   : s64;
g_LineNo        : s64;
g_MapVersion    : MapVersion;
g_Pos           : s64;

TokenType :: enum u32 {
    LBRACE;
    RBRACE;
    LPAREN;
	RPAREN;
	LBRACKET;
	RBRACKET;
	NUMBER;
	STRING;
	COMMENT;
	TEXNAME;
	UNKNOWN;
	END_OF_INPUT;
}

#scope_export

using MapVersion :: enum {
    QUAKE;
    VALVE_220;
}

QuakeVertex :: struct {
    x, y, z : float64;
}

QuakeTexture :: struct {
    xOffset, yOffset    : float64;
    rotation            : float64;
    xScale, yScale      : float64;
}

Valve220Texture :: struct {
    tx1, ty1, tz1, tOffset1 : float64;
    tx2, ty2, tz2, tOffset2 : float64;
}

QuakeFace :: struct {
    vertices    : [3] QuakeVertex;
    textureName : string;
    
    textureData : union {
        quakeTexture : QuakeTexture;
        valveTexture : Valve220Texture;
    }
}

QuakeBrush :: struct {
    faces : [..] QuakeFace;
}

Property :: struct {
    key     : string;
    value   : string;
}

PointEntity :: struct {
    properties  : [..] Property;    
}

BrushEntity :: struct {
    properties  : [..] Property;
    brushes     : [..] QuakeBrush;
}

QuakeEntity :: struct {
    entityData : union {
        pointEntity : PointEntity;
        brush       : QuakeBrush;
        brushEntity : BrushEntity;     
    }
    subEntities : [..] QuakeEntity;
}

QuakeMap :: struct {
    quakeEntities : [..] QuakeEntity;
}

AdvanceToNextNonWhitespace :: (mapData : string) {
    while mapData[g_Pos] == #char " " g_Pos += 1;
}

AdvanceToNextLine :: (mapData : string) {
    while mapData[g_Pos] != #char "\n" g_Pos += 1;
    if mapData[g_Pos] == #char "\r" g_Pos += 1;
}

SkipLineBreaksAndWhitespaces :: (mapData : string) {
    while mapData[g_Pos] == #char " "
        || mapData[g_Pos] == #char "\n"
        || mapData[g_Pos] == #char "\r" {
            g_Pos += 1;
        }
}

IsNumeric :: (c : u8) -> bool {
    return c >= #char "0" && c <= #char "9";
}

IsLiteral :: (c : u8) -> bool {
    return c >= #char "a" && c <= #char "z"
    || c >= #char "A" && c <= #char "Z";
}

GetToken :: (mapData : string) -> TokenType {
    result := TokenType.UNKNOWN;

    SkipLineBreaksAndWhitespaces(mapData);
    while mapData[g_Pos] == #char "/" { // Skip comments
        AdvanceToNextLine(mapData);
        SkipLineBreaksAndWhitespaces(mapData);
    }

    c := mapData[g_Pos];

    
    if c == #char "{" result = .LBRACE;
    else if c == #char "}"  result = .RBRACE;
    else if c == #char "("  result = .LPAREN;
    else if c == #char ")"  result = .RPAREN;
    else if c == #char "["  result = .LBRACKET;
    else if c == #char "]"  result = .RBRACKET;
    else if c == #char "\"" result = .STRING;
    else if IsNumeric(c) || c == #char "-"  result = .NUMBER;
    else if IsLiteral(c) result = .TEXNAME;
    else result = .UNKNOWN; // should not happen

    return result;
}

Check :: (got : TokenType, expected : TokenType) {
    assert(got == expected, "Parsed token: %, but expected: %\n", got, expected);
}

AdvanceCursor :: (count : s64) {
    g_Pos += count;
}

GetVertex :: (mapData : string) -> QuakeVertex {
    Check(GetToken(mapData), .LPAREN); AdvanceCursor(1);
    Check(GetToken(mapData), .NUMBER); GetNumber(mapData);
    Check(GetToken(mapData), .NUMBER); GetNumber(mapData);
    Check(GetToken(mapData), .NUMBER); GetNumber(mapData);
    Check(GetToken(mapData), .RPAREN); AdvanceCursor(1);

    return .{};
}

GetQuakeBrush :: (mapData : string) -> QuakeBrush {
    brush : QuakeBrush;    

    // Get 3 points of plane

    GetVertex(mapData);
    GetVertex(mapData);
    GetVertex(mapData);
    
    // Get texture name

    Check(GetToken(mapData), .STRING); GetString(mapData);

    // Get texture coords

    Check(GetToken(mapData), .LBRACKET); GetTextureCoords(mapData);
    
    return brush;
}

GetTextureCoords :: (mapData : string) {
    Check(GetToken(mapData), .LBRACKET); AdvanceCursor(1);
    Check(GetToken(mapData), .NUMBER); GetNumber(mapData);
    Check(GetToken(mapData), .NUMBER); GetNumber(mapData);
    Check(GetToken(mapData), .NUMBER); GetNumber(mapData);
    Check(GetToken(mapData), .NUMBER); GetNumber(mapData);
    Check(GetToken(mapData), .RBRACKET); AdvanceCursor(1);

    Check(GetToken(mapData), .LBRACKET); AdvanceCursor(1);
    Check(GetToken(mapData), .NUMBER); GetNumber(mapData);
    Check(GetToken(mapData), .NUMBER); GetNumber(mapData);
    Check(GetToken(mapData), .NUMBER); GetNumber(mapData);
    Check(GetToken(mapData), .NUMBER); GetNumber(mapData);
    Check(GetToken(mapData), .RBRACKET); AdvanceCursor(1);

    Check(GetToken(mapData), .NUMBER); GetNumber(mapData);
    Check(GetToken(mapData), .NUMBER); GetNumber(mapData);
    Check(GetToken(mapData), .NUMBER); GetNumber(mapData);
}

GetProperties :: (mapData : string) -> PointEntity {
    pointEntity : PointEntity;

    Check(GetToken(mapData), .STRING);
    while GetToken(mapData) == .STRING {
        Check(GetToken(mapData), .STRING);
        key := GetString(mapData);
        Check(GetToken(mapData), .STRING);
        value := GetString(mapData);
        array_add(*pointEntity.properties, Property.{key, value});
    }

    for pointEntity.properties {
        print("key: %, value: %\n", it.key, it.value);
    }

    return pointEntity;
}

GetString :: (mapData : string) -> string {
    charArray : [..] u8;
    AdvanceCursor(1);
    while mapData[g_Pos] != #char "\"" {
        array_add(*charArray, mapData[g_Pos]);
        AdvanceCursor(1);
    }
    AdvanceCursor(1); // Go over closing ' " '.

    result : string;
    result.count = charArray.count;
    result.data = alloc(charArray.count);
    memcpy(result.data, charArray.data, charArray.count);
    free(charArray.data);

    return result;
}

GetEntity :: (mapData : string) {
    Check(GetToken(mapData), .LBRACE); AdvanceCursor(1);

    if GetToken(mapData) == .LPAREN GetQuakeBrush(mapData);
    else if GetToken(mapData) == .STRING GetProperties(mapData);
    
    // Current Entity could contain another entity...

    if GetToken(mapData) == .LBRACE GetEntity(mapData); 

    Check(GetToken(mapData), .RBRACE); AdvanceCursor(1);
}

GetNumber :: (mapData : string) -> float64 {
    number : [..] u8;
    if mapData[g_Pos] == #char "-" {
        array_add(*number, #char "-");
        AdvanceCursor(1);
    }

    assert(IsNumeric(mapData[g_Pos]), "Expected a numeric symbol, but got: %\n", mapData[g_Pos]); // TODO: Shouldnt I use Check() here?

    while IsNumeric(mapData[g_Pos]) || mapData[g_Pos] == #char "e" || mapData[g_Pos] == #char "-" {
        array_add(*number, mapData[g_Pos]);
        AdvanceCursor(1);
    }
    
    numberString : string;
    numberString.count = number.count;
    numberString.data = alloc(number.count);
    memcpy(numberString.data, number.data, number.count);

    result := string_to_float64(numberString);
    free(number.data);
    free(numberString.data);

    return result;
}

ParseQuakeMap :: (file : string, mapVersion := QUAKE) -> QuakeMap {
    
    mapData := read_entire_file(file);

    g_InputLength = mapData.count;
    g_LineNo = 1;
    g_MapVersion = mapVersion;
    
    while g_Pos < g_InputLength {
        
        // AdvanceCursor(1);
        // print("Token: %\n", GetToken(mapData));
        GetEntity(mapData);
        //g_Pos += 1;
    }

    return .{};
}




