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

MapVersion :: enum u32 {
    QUAKE;
    VALVE_220;
}

QuakeVertex :: struct {
    x, y, z : float;
}

QuakeTexture :: struct {
    xOffset, yOffset    : float;
    rotation            : float;
    xScale, yScale      : float;
}

Valve220Texture :: struct {
    tx1, ty1, tz1, tOffset1  : float;
    tx2, ty2, tz2, tOffset2  : float;
    rotation, scaleX, scaleY : float;
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
    properties  : [..] Property;
    brushes     : [..] QuakeBrush;
}

QuakeMap :: struct {
    entities : [..] QuakeEntity;
}

AdvanceToNextNonWhitespace :: (mapData : string) {
    while mapData[g_Pos] == #char " " g_Pos += 1;
}

AdvanceToNextLine :: (mapData : string) {
    while mapData[g_Pos] != #char "\n" {
        g_Pos += 1;
        if !(g_Pos < mapData.count) return;
    }
    if !(g_Pos < mapData.count) return;
    if mapData[g_Pos] == #char "\r"     g_Pos += 1;
}

SkipLineBreaksAndWhitespaces :: (mapData : string) {
    while mapData[g_Pos] == #char " "
        || mapData[g_Pos] == #char "\n"
        || mapData[g_Pos] == #char "\r" {
            g_Pos += 1;
            if !(g_Pos < mapData.count) return;
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
    if !(g_Pos < mapData.count) return .END_OF_INPUT;
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
    Check(GetToken(mapData), .NUMBER); n1 := GetNumber(mapData);
    Check(GetToken(mapData), .NUMBER); n2 := GetNumber(mapData);
    Check(GetToken(mapData), .NUMBER); n3 := GetNumber(mapData);
    Check(GetToken(mapData), .RPAREN); AdvanceCursor(1);

    return .{n1, n2, n3};
}

GetQuakeFace :: (mapData : string) -> QuakeFace {
    result : QuakeFace;    

    // Get 3 points of plane    

    result.vertices[0] = GetVertex(mapData);
    result.vertices[1] = GetVertex(mapData);
    result.vertices[2] = GetVertex(mapData);
    
    // Get texture name

    Check(GetToken(mapData), .TEXNAME); result.textureName = GetTexName(mapData);

    // Get texture coords

    Check(GetToken(mapData), .LBRACKET); result.textureData.valveTexture = GetValve220TextureCoords(mapData);

    return result;
}

GetQuakeBrush :: (mapData : string) -> QuakeBrush {
    brush : QuakeBrush;

    while GetToken(mapData) != .RBRACE {
        face := GetQuakeFace(mapData);
        array_add(*brush.faces, face);
    }
    AdvanceCursor(1); // Go over RBRACE
    
    return brush;
}

GetValve220TextureCoords :: (mapData : string) -> Valve220Texture {

    result : Valve220Texture;

    Check(GetToken(mapData), .LBRACKET); AdvanceCursor(1);
    Check(GetToken(mapData), .NUMBER); result.tx1 = GetNumber(mapData);
    Check(GetToken(mapData), .NUMBER); result.ty1 = GetNumber(mapData);
    Check(GetToken(mapData), .NUMBER); result.tz1 = GetNumber(mapData);
    Check(GetToken(mapData), .NUMBER); result.tOffset1 = GetNumber(mapData);
    Check(GetToken(mapData), .RBRACKET); AdvanceCursor(1);

    Check(GetToken(mapData), .LBRACKET); AdvanceCursor(1);
    Check(GetToken(mapData), .NUMBER); result.tx2 = GetNumber(mapData);
    Check(GetToken(mapData), .NUMBER); result.ty2 = GetNumber(mapData);
    Check(GetToken(mapData), .NUMBER); result.tz2 = GetNumber(mapData);
    Check(GetToken(mapData), .NUMBER); result.tOffset2 = GetNumber(mapData);
    Check(GetToken(mapData), .RBRACKET); AdvanceCursor(1);

    Check(GetToken(mapData), .NUMBER); result.rotation = GetNumber(mapData);
    Check(GetToken(mapData), .NUMBER); result.scaleX = GetNumber(mapData);
    Check(GetToken(mapData), .NUMBER); result.scaleY = GetNumber(mapData);

    return result;
}

GetProperties :: (mapData : string) -> [..] Property {
    result : [..] Property;

    Check(GetToken(mapData), .STRING);
    while GetToken(mapData) == .STRING {
        Check(GetToken(mapData), .STRING);
        key := GetString(mapData);
        Check(GetToken(mapData), .STRING);
        value := GetString(mapData);
        array_add(*result, Property.{key, value});
    }

    for result {
        print("key: %, value: %\n", it.key, it.value);
    }

    return result;
}

CharArrayToString :: (charArray : [] u8) -> string #must {
    result : string;
    result.count = charArray.count;
    result.data = alloc(charArray.count);
    memcpy(result.data, charArray.data, charArray.count);
    
    free(charArray.data);

    return result;
}

GetTexName :: (mapData : string) -> string {
    charArray : [..] u8;
    while mapData[g_Pos] != #char " " {
        array_add(*charArray, mapData[g_Pos]);
        AdvanceCursor(1);
    }

    result := CharArrayToString(charArray);

    return result;
}

GetString :: (mapData : string) -> string {
    charArray : [..] u8;
    AdvanceCursor(1); // Go over opening ' " '
    while mapData[g_Pos] != #char "\"" {
        array_add(*charArray, mapData[g_Pos]);
        AdvanceCursor(1);
    }
    AdvanceCursor(1); // Go over closing ' " '.

    result := CharArrayToString(charArray);

    return result;
}

GetEntity :: (mapData : string) -> QuakeEntity, bool {

    if GetToken(mapData) == .END_OF_INPUT return .{}, false;

    entity : QuakeEntity;

    Check(GetToken(mapData), .LBRACE); AdvanceCursor(1);

    // Parse the entity
    // Two cases are possible:
    // The entity only consists of properties: It is a point entity.
    // The entity consists of both properties and brushes: It is a brush entity.
    // The worldspawn is a brush entity in that it defines some global properties
    // usually followed by a long list of brushes that make up the static world
    // geometry.

    if      GetToken(mapData) == .STRING entity.properties = GetProperties(mapData);
    while GetToken(mapData) == .LBRACE {
        AdvanceCursor(1);
        if GetToken(mapData) == .LPAREN array_add(*entity.brushes, GetQuakeBrush(mapData));
    }    

    // Current entity is done

    Check(GetToken(mapData), .RBRACE); AdvanceCursor(1);

    return entity, true;
}

GetNumber :: (mapData : string) -> float {
    number : [..] u8;
    if mapData[g_Pos] == #char "-" {
        array_add(*number, #char "-");
        AdvanceCursor(1);
    }

    assert(IsNumeric(mapData[g_Pos]), "Expected a numeric symbol, but got: %\n", mapData[g_Pos]); // TODO: Shouldnt I use Check() here?

    while IsNumeric(mapData[g_Pos]) || mapData[g_Pos] == #char "e" || mapData[g_Pos] == #char "-" || mapData[g_Pos] == #char "." {
        array_add(*number, mapData[g_Pos]);
        AdvanceCursor(1);
    }
    
    numberString : string;
    numberString.count = number.count;
    numberString.data = alloc(number.count);
    memcpy(numberString.data, number.data, number.count);

    result := string_to_float(numberString);
    free(number.data);
    free(numberString.data);

    return result;
}

ParseQuakeMap :: (file : string, mapVersion := MapVersion.QUAKE) -> QuakeMap {
    
    mapData := read_entire_file(file);

    g_InputLength = mapData.count;
    g_LineNo = 1;
    g_MapVersion = mapVersion;
    
    quakeMap : QuakeMap;
    found := true;
    entity : QuakeEntity;
    while found {
        entity, found = GetEntity(mapData);
        if found {
            array_add(*quakeMap.entities, entity);
        }
    }

    if !found && g_Pos < g_InputLength {
        print("WARNING (Quake MAP parser): No more entities found but not yet at the end of the file: %\n", file);
    }

    return quakeMap;
}




