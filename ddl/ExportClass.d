/+
   Copyright (c) 2006 Eric Anderton, Tomasz Stachowiak
   
   Permission is hereby granted, free of charge, to any person
   obtaining a copy of this software and associated documentation
   files (the "Software"), to deal in the Software without
   restriction, including without limitation the rights to use,
   copy, modify, merge, publish, distribute, sublicense, and/or
   sell copies of the Software, and to permit persons to whom the
   Software is furnished to do so, subject to the following
   conditions:

   The above copyright notice and this permission notice shall be
   included in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
   OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
   HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
   WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
   OTHER DEALINGS IN THE SOFTWARE.
+/
module ddl.ExportClass;

import ddl.DynamicLibrary;
import ddl.Mangle;
import ddl.Demangle;
import ddl.DDLException;

import ddl.Utils;

import tango.text.Regex;

/**
	Dynamic class loading utility.
	
	ExportClass provided dynamic class-loading support, as a blended compile-time, run-time
	solution.  
*/
class ExportClass(T) {
   alias T           baseType;
   ClassInfo         classInfo;
   char[]            name;
   DynamicLibrary    dynamicLib;

   this(ClassInfo classInfo, char[] name, DynamicLibrary lib) {
   	  if (name.length > 2 && name[0..2] == "_D") {
   	  	name = name[2..$];
   	  }
   	  
      this.classInfo = classInfo;
      this.name = name;
      this.dynamicLib = lib;
   }

   bool isAbstract() {
      assert (classInfo.vtbl.length > 1);
      // is this the proper way to check whether a class is abstract ?
      return classInfo.vtbl[1] is null;
   }

   baseType newObject()() {
      assert (!isAbstract);

      auto ctor = cast(Object function (Object)) dynamicLib.getSymbol(
         "_D" ~ name ~ mangleSymbolName!("_ctor")
         ~ "MF"
         ~ "ZC" ~ name).address;

      debug (DDL) debugLog ("ctor: {:x8} {:x8}", ctor, classInfo);

      auto obj = _d_newclass(classInfo);
      debug (DDL) debugLog ("obj: {:x8}",  obj);

      if (ctor) ctor(obj);
      else {
         auto Regex ctorMatch = new Regex(
               `^_D` ~ name ~ mangleSymbolName!("_ctor")
               ~ `MF` ~ `.*`
               ~ `ZC` ~ name ~ `$`);

         foreach (mod; dynamicLib.getModules) {
            foreach (sym; mod.getSymbols) {
               if (0 != ctorMatch.test(sym.name)) {
                  throw new DDLException("Class " ~ name ~ " doesn't have a default ctor");
               }
            }
         }

         // there are no ctors in this class
      }

      return cast(baseType)obj;
   }
   
	baseType newObject(P...)(P p) {
		assert (!isAbstract);

		char[] symName = "_D" ~ name ~ mangleSymbolName!("_ctor") ~ "MF";
		foreach (par; P) {
			symName ~= par.mangleof;
		}
		symName ~= "ZC" ~ name;
		auto ctor = cast(Object function (P, Object)) dynamicLib.getSymbol(symName).address;
		assert (ctor !is null, symName);

		auto obj = _d_newclass(classInfo);
		ctor(p, obj);
		return cast(baseType)obj;
	}

   /+baseType newObject(P1)(P1 p1) {
      assert (!isAbstract);

      auto ctor = cast(Object function (P1, Object)) dynamicLib.getSymbol(
         "_D" ~ name ~ mangleSymbolName!("_ctor")
         ~ "MF" ~ P1.mangleof
         ~ "ZC" ~ name).address;
      assert (ctor !is null);

      auto obj = _d_newclass(classInfo);
      ctor(p1, obj);
      return cast(baseType)obj;
   }   


   baseType newObject(P1, P2)(P1 p1, P2 p2) {
      assert (!isAbstract);

		char[] symName =
         "_D" ~ name ~ mangleSymbolName!("_ctor")
         ~ "MF" ~ P1.mangleof ~ P2.mangleof
         ~ "ZC" ~ name;
         
      auto ctor = cast(Object function (P1, P2, Object)) dynamicLib.getSymbol(symName).address;
      assert (ctor !is null, symName);

      auto obj = _d_newclass(classInfo);
      ctor(p1, p2, obj);
      return cast(baseType)obj;
   }   +/
}
