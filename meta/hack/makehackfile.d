module meta.hack.makehackfile;

// Create the static hackgenerate file.

import std.stdio;

void writeheader()
{
  writefln(r"// Autogenerated file - do not edit" \n);
  writefln("template hackgenerate(int num, alias gen)");
  writefln("{"\n `  pragma(msg, "Table is too large!");` \n `  static assert(0);` \n "}" \n);
}

void writefunc(int i)
{
 writefln(" template hackgenerate(int num :", i, ", alias gen)");
 writefln(" {");
 writef(" const typeof(gen!(0)) [] hackgenerate = [");
 
 for (int j=0; j <= i; ++j)  {
   if (j%6==0) { writef(\n "    "); }
   writef("gen!(", j, ")");
   if (j!=i) writef(", ");
 }
 writefln(" ];" \n "}" \n );
}

void main()
{
  writeheader();
  for (int i=0; i<128; ++i) {
     writefunc(i);
  }
}