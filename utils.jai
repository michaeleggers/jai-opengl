
ArrayReverse :: (a : *[..] $T) {
    if a.count == 0 return;
    lastIndex : s64 = (a.count-1)/2;
    for i : 0..lastIndex {        
        tmp := a.data[i];
        a.data[i] = a.data[a.count-1 - i];
        a.data[a.count-1 - i] = tmp;
    }
}

// Converts a string with the format "x y z" to a Vector3.

NumberStringToFloat :: (input : string, pos : s64) -> float, s64 {
    charString : [..] u8;
    c := input[pos];

    while c == #char " " {
        pos += 1;
        if pos >= input.count break;
        c = input[pos];
    }

    if c == #char "-" {
        array_add(*charString, c);         
        pos += 1;
        if pos >= input.count return 0.0, pos;
        c = input[pos];
    }
    
    while c >= #char "0" && c <= #char "9" {    
        array_add(*charString, c);        
        pos += 1;
        if pos >= input.count break;
        c = input[pos];
    }

    numberString : string;
    numberString.count = charString.count;
    numberString.data = alloc(charString.count);
    memcpy(numberString.data, charString.data, charString.count);

    number := string_to_float(numberString);
    array_free(charString);
    free(numberString.data);

    return number, pos;
}

OriginStringToVector3 :: (originString : string) -> Vector3 {
    result : [3] float;
    pos := 0;      
    i := 0;  
    while pos < originString.count && i < 3 {        
        result[i], pos = NumberStringToFloat(originString, pos);
        i += 1;        
    }    

    return Vector3.{result[0], result[1], result[2]};
}