/+
	Copyright (c) 2005-2006 Eric Anderton
        
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
	Default loader registry implemenation, suitable for quick prototyping or
	kitchen-sink style support for DDL loading.
	
	Authors: Eric Anderton
	License: BSD Derivative (see source for details)
	Copyright: 2005-2006 Eric Anderton
*/
module ddl.DefaultRegistry;

private import ddl.LoaderRegistry;
//private import ddl.ar.ArchiveLoader;
private import ddl.omf.OMFLoader;
//private import ddl.ddl.DDLLoader;
private import ddl.elf.ELFObjLoader;
private import ddl.insitu.InSituLoader;
//private import ddl.coff.COFFLoader;

/**
	Default Loader Registry implementation.
	
	Pulls in support for all standard loader types.  The order of loader registration
	is different for each platform, to help make things more efficent for typical cases.
	
	See ddl.LoaderRegistry for more details.
*/
class DefaultRegistry : LoaderRegistry{
	/**
		Default constructor.
	*/
	public this(){
		version(Windows){ // order optimized per OS
			register(new OMFLibLoader());
			register(new OMFObjLoader());
			//register(new DDLLoader());
	//		register(new InSituLibLoader());
			register(new InSituMapLoader());
			//register(new ArchiveLoader());			
	//		register(new COFFObjLoader());			
			register(new ELFObjLoader());			
		}
		else{
			//register(new ArchiveLoader());
			register(new ELFObjLoader());
			//register(new DDLLoader());
	//		register(new InSituLibLoader());			
			register(new OMFLibLoader());
			register(new OMFObjLoader());
			register(new InSituMapLoader());			
	//		register(new COFFObjLoader());			
		}
	}
}
