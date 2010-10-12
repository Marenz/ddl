module meta.feqtest;

import meta.math;
import meta.conv;
import std.stdio;
import std.math;
import meta.ctype;

template extractExponent(char [] s)
{
    const int extractExponent = parseExponent!(s[parseMantissaConsumed!(s)..$]);
}

static assert(extractExponent!("3.34e467") == 467);

//   bool feq!(constant real x)(variable real y)
//
// Return true if and only if the real variable y is equal to the constant x,
// to the number of decimal places specified in x.
//  Example:  feq!("3.180")(3.1796)  is true, but
//            feq!("3.1800")(3.1796) is false.

template feq(char [] x)
{
    bool feq(real y) {
        return fabs(y-atof!(x)) < 0.5L * meta.math.pow!(10.0L, extractExponent!(x)-decimalplaces!(x));
    }
}


//-------------------------------------------------------------------
//  dprintf() -- typesafe printf, with compile-time
//               checking of the format string.
//-------------------------------------------------------------------

// of the form "%s"
template str2type(char ch)
{
    static if (ch=='s')         alias char [] str2type;
    else static if (ch == 'c') alias char str2type;
    else static if (ch == 'd') alias int str2type;
    else static if (ch == 'f' || ch=='e' || ch=='g' || ch == 'F' || ch=='E' || ch=='G' || ch=='a' || ch =='A')
        alias double str2type;
    else {
        pragma(msg, "Unrecognised type character '"~ ch ~ "' in dprintf");
        static assert(0);
    }
}

// Constructs a string made up of each char that follows each % sign.
template getFormatChars(char [] str, bool gotpercent=false)
{
    static if (str.length==0){
        static if (gotpercent) {
            pragma(msg, "Error in format string");
            static assert(0);
        } else const char [] getFormatChars = "";
  } else static if (!gotpercent && str[0]=='%') {
     const char [] getFormatChars = getFormatChars!(str[1..$], true);  
  } else static if (gotpercent && (str[0]=='.' || str[0]=='-' || str[0]=='+' || isdigit!( (str[0]) ) ) ) {
     const char [] getFormatChars = getFormatChars!(str[1..$], true);
  } else static if (gotpercent) {
      const char [] getFormatChars = str[0] ~ getFormatChars!(str[1..$], false);
  } else 
      const char [] getFormatChars = getFormatChars!(str[1..$], false); 
}

template dprintfT(char [] fstr, char [] str)
{
    static if ( fstr.length==0)
        void dprintfT() {
            printf(str);
        }
    else static if ( fstr.length==1)
        void dprintfT(str2type!((fstr[0])) p1) {
            printf(str, p1);
        }
    else static if (fstr.length==2)
        void dprintfT(str2type!((fstr[0])) p1, str2type!((fstr[1])) p2) { 
            printf(str, p1, p2);
        }       
    else {
      pragma(msg, "Too many parameters in dprintf!");
      // (but it's trivial to add more)
      static assert(0);
    }
}

// Just a demo to show we can manipulate the string.
template dprintfln(char [] x)
{
   alias dprintfT!(getFormatChars!(x), x~"\n") dprintfln;
}


void main()
{
    real x = 3.1796;
    if ( feq!("3.180")(x) ) {
        writefln("equal");
    } else writefln("not eq");

    assert(  feq!("32.180")(32.1804) );
    assert( !feq!("32.180")(32.1806) );
    assert( feq!("-32.180e45")(-3.21803e46) );
    assert( feq!("-32.180e45")(-3.218049999e46) );
    assert( feq!("-1e-20")(-9.5e-21) );
    
    
    int q=3;
    double z = 3.1415;
    dprintfln!("This is q=%d")(q);
    dprintfln!("%d")(7);
    dprintfln!("This is a float %+2.7E and an int %d")(z, q);    
}