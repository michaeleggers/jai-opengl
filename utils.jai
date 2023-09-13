
ArrayReverse :: (a : *[..] $T) {
    if a.count == 0 return;
    lastIndex : s64 = (a.count-1)/2;
    for i : 0..lastIndex {        
        tmp := a.data[i];
        a.data[i] = a.data[a.count-1 - i];
        a.data[a.count-1 - i] = tmp;
    }
}
