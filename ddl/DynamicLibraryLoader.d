/+
	Copyright (c) 2005,2006 Eric Anderton
        
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
	Provides DynamicLibrary loading support.
	
	Authors: Eric Anderton
	License: BSD Derivative (see source for details)
	Copyright: 2005,2006 Eric Anderton
*/
module ddl.DynamicLibraryLoader;

private import ddl.DynamicLibrary;
private import ddl.LoaderRegistry;
private import ddl.FileBuffer;


/**
	Base class for all dynamic library loaders.
*/
abstract class DynamicLibraryLoader{
	/**
		Returns: the type for this library.
	*/
	public char[] getLibraryType();

	/**
		The implementaiton is understood to check the file by inspecting its contents.
		The implementor must be sure to not advance the internal buffer pointer, so that
		future checks against the buffer can all begin at the same location.
	
		Returns: true if the file can be loaded by this loader, false if it cannot.
	*/
	public bool canLoadLibrary(FileBuffer file);
	
	/**
		Loads a binary file.
	
		Returns: the library stored in the provided file.
		Params:
			file = the file that contains the binary library data.
	*/
	public DynamicLibrary load(LoaderRegistry registry,FileBuffer file);
}
