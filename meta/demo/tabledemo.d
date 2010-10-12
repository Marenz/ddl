

// Create a constant array of long or ulong-sized items. Needs to be cast back to
// long[] or ulong[].
template generateArrayAsChar(alias entry, int n)
{
  static if ( entry!(0).sizeof == dchar.sizeof) {
      // int or uint sized items
      static if (n==0) {
        const dchar [] generateArrayAsChar = ""d  ~ cast(dchar)entry!(n);
      } else {
        const dchar[] generateArrayAsChar = generateArrayAsChar!(entry, n-1) ~ cast(dchar)entry!(n);
      }
  } else static if ( entry!(0).sizeof == 2*dchar.sizeof) {
      // long or ulong sized items
      static if (n==0) {
        const dchar [] generateArrayAsChar = ""d  
                ~ cast(dchar)entry!(n) ~ cast(dchar)(entry!(n)>>>32);
      } else {
        const dchar[] generateArrayAsChar = generateArrayAsChar!(entry, n-1)
            ~ cast(dchar)entry!(n)  ~ cast(dchar)(entry!(n)>>32);
      }
  }
}

template generateArray(alias entry, int n)
{
  const typeof(entry!(0)) [] generateArray = cast(typeof(entry!(0)) [])generateArrayAsChar!(entry, n);
}

// The ubiquitous factorial function
//
// Returns correct value for n=0 (factorial!(0)=1).
template factorial(int n)
{
  static if (n<2) const uint factorial = 1;
  else const uint factorial = n * factorial!(n-1);
}

// Make an array of all the factorials from 0 to 13 (14!> ulong.max)
const smallfactorials = generateArray!(factorial, 13);


/+
// Make an array of all the factorials from 0 to 20 (21!> ulong.max)
const ulong [] smallfactorials;
static this()
{
    smallfactorials = cast(uint []) generateArrayAsChar!(factorial, 20);
}
+/
import std.stdio;

void main()
{
  for (int i=0; i<smallfactorials.length; ++i) {
     writefln(i, "  ", smallfactorials[i]);
  }
}
