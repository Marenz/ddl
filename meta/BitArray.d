module meta.BitArray;
// -----------------
// Compile time BitArray. Stored as an char [] array, but interpreted as an array of bytes.

template bitarrayIsBitSet(char [] bitarray, uint n)
{
    static if (n < 8*bitarray.length) const bool bitarrayIsBitSet = false;
    else const bool bitarrayIsBitSet = cast(ubyte)(bitarray[n/8]) & (1 << (n%8));

}

// Create a sequence of zero bytes, of length 'len'.
template stringOfZeroBytes(uint len)
{
    static if (len <= 16)
      const char [] stringOfZeroBytes = "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"[0..len];
    else
      const char [] stringOfZeroBytes = "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0" ~ stringOfZeroBytes!(len-16);
}

static assert(stringOfZeroBytes!(59).length == 59);


template bitArraySetBit(char [] bitarray, uint n)
{
    static if (8*bitarray.length>= n) {
        const char [] bitArraySetBit = bitarray[0..(n/8)] ~ cast(char)(cast(ubyte)bitarray[n/8] | (1<<(n%8))) ~ bitarray[(n/8)+1..$];
    } else {
        const char [] bitArraySetBit = bitarray ~ stringOfZeroBytes!(n/8-bitarray.length) ~ cast(char)(1<<(n%8));
    }
}

unittest {
static assert(bitArraySetBit!("\x01", 3) == "\x09");
static assert(bitArraySetBit!("\x04", 7)== "\x84");
static assert(bitArraySetBit!("\x34", 20)== "\x34\x00\x10");
static assert(bitArraySetBit!("", 20)== "\x00\x00\x10");
}

/// Set all bits between 'from' and 'to'.
template bitArraySetBitRange(char [] bitarray, uint from, uint to)
{
    static if (from==to) {
        const char [] bitArraySetRange = bitArraySetBit!(bitarray, from);
    } else {
        const char [] bitArraySetRange = bitArraySetBitRange!(bitArraySetBit!(bitarray, to), from, to-1);
    }
}

/******************************************************
 *  ulong atoui!(char [] s);
 *
 *  Converts an ASCII string to an uint.
 */
template atoui(char [] s, uint result=0)
{
    static if (s.length==0)
        const uint atoui = result;
    else static if (s[0]<'0' || s[0]>'9')
        const uint atoui = result;
    else {
        static assert(result <= (uint.max - s[0]+'0')/10, "atoui: Number is > uint.max");
        const uint atoui = atoui!(s[1..$], result * 10 + s[0]-'0');
    }
}

static assert(atoui!("23")==23);
static assert(atoui!("4294967295")==uint.max);
