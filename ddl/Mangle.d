/+
	Copyright (c) 2005 Eric Anderton, Don Clugston
	
	Based on demangler.d written by James Dunne, Copyright (C) 2005
        
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
/*
	Template Library to support compile-time symbol demangling.  
	This is put to good use by the DynamicLibrary class.

	Authors: Eric Anderton, Don Clugston
	License: BSD Derivative (see source for details)
	Copyright: 2005 Eric Anderton
*/
module ddl.Mangle;

import meta.conv;

import Integer = tango.text.convert.Integer;

/*  char [] mangleSymbolName!(char [] name);
 *  Convert a name of the form "module.func" to the form
 *  "6module4func".
 */
template mangleSymbolName(char[] text, char [] latestword="")
{
  static if (text.length<1)  {
     static if (latestword.length==0)
            const char[] mangleSymbolName = "";
     else const char[] mangleSymbolName = itoa!(latestword.length) ~ latestword;
  } else static if (text[0]=='.') {
      const char[] mangleSymbolName =
      itoa!(latestword.length) ~ latestword ~ .mangleSymbolName!(text[1..(text.length)], "");
  } else
     const char[] mangleSymbolName = .mangleSymbolName!( text[1..(text.length)], latestword ~ text[0..(1)]);
}

/*
	Runtime function that converts a name of the form "module.func" to the form "6module4func" per
	the D ABI name-mangling specification.
*/
char[] mangleNamespace(char[] text){
	char[] result;
	char[] buffer = new char[16];
	uint i=0;
	uint last=0;
	while(i < text.length){
		if(text[i] == '.'){
			result ~= Integer.format(buffer,(i-last)) ~ text[last..i];
			i++;
			last = i;
		}
		i++;
	}
	result ~= Integer.format(buffer,(text.length-last)) ~ text[last..text.length];
	return result;
}
