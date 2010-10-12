/+
	Copyright (c) 2005-2007  J Duncan, Eric Anderton
        
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
/**
	
	Authors: J Duncan, Eric Anderton
	License: BSD Derivative (see source for details)
	Copyright: 2005, 2006 J Duncan, Eric Anderton
*/

module ddl.coff.COFFLoader;

import ddl.coff.COFFObject;
import ddl.coff.COFFLibrary;
import ddl.coff.COFFModule;

private import ddl.DynamicLibrary;
private import ddl.DynamicLibraryLoader;
private import ddl.LoaderRegistry;
private import ddl.FileBuffer;
private import ddl.Utils;

class COFFObjLoader : DynamicLibraryLoader{
	public static char[] typeName = "COFFOBJ";
	
	public char[] getLibraryType(){
		return(typeName);
	}
		
	public bool canLoadLibrary(FileBuffer file){
		ubyte[] test = cast(ubyte[])file.get(2,false);
		return test[0] == 0x80;
//		return test[0] == 0x4c && test[1] == 0x01;
	}
	
	public DynamicLibrary load(LoaderRegistry registry,FileBuffer file){
		COFFLibrary lib = new COFFLibrary(file.getPath.toString());
		COFFModule mod = new COFFModule(file);
		lib.addModule(mod);
		return lib;
	}
}

class COFFDLLLoader : DynamicLibraryLoader{
	public static char[] typeName = "COFFDLL";
	public static char[] fileExtension = "dll";
	
	public char[] getLibraryType(){
		return(typeName);
	}
	
	public char[] getFileExtension(){
		return(fileExtension);
	}	
		
	public bool canLoadLibrary(FileBuffer file){
		ubyte[] test = cast(ubyte[])file.get(2,false);
		return test[0] == 'M' && test[1] == 'Z';
	}
	
	public DynamicLibrary load(LoaderRegistry registry,FileBuffer file){

		throw new Exception("COFF/PE DLL files are not supported");

		return null;
	}
}


class COFFExeLoader : DynamicLibraryLoader{
	public static char[] typeName = "COFFEXE";
	public static char[] fileExtension = "exe";
	
	public char[] getLibraryType(){
		return(typeName);
	}
	
	public char[] getFileExtension(){
		return(fileExtension);
	}	
		
	public bool canLoadLibrary(FileBuffer file){
		ubyte[] test = cast(ubyte[])file.get(2,false);
		return test[0] == 'M' && test[1] == 'Z';
	}
	
	public DynamicLibrary load(LoaderRegistry registry,FileBuffer file){

		throw new Exception("COFF/PE files are not supported");

		return null;
	}
}

