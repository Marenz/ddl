/+
   Copyright (c) 2006,2007 Eric Anderton, Tomasz Stachowiak
   
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

module ddl.PathLibrary;

private import ddl.DynamicLibrary;
private import ddl.DynamicModule;
private import ddl.LoaderRegistry;
private import ddl.Linker;
private import ddl.Demangle;
private import ddl.Attributes;
private import ddl.ExportSymbol;
private import ddl.Utils;

private import tango.io.device.File;
//private import tango.io.FileConst;
private import tango.io.FilePath;
private import Text=tango.text.Util;

//TODO: remove parsing code here and use what's available in Demangle
   

//TODO: insensitive to file time/date changes
//TODO: use delegate pass-forward to eliminate double-looping with processing file listings

/**
	The PathLibrary maps a directory path as a tree-based resource, where libraries
	and modules may be found for loading.
	
	The class intends to behave as lazily as possible, first by only loading the root-most
	libraries and modules compatible with the provided registry.  Calls to getModuleForSymbol()
	will trigger searches into the appropriate set of directories to match that namespace.
		
	The namespace-to-module mapping is accomplished via any registered namespaceTranslators.
	The DefaultPathLibrary provides a typical "path is namespace" translation.
*/
class PathLibrary : DynamicLibrary{
   protected bool isPreLoaded;
   protected bool isFullyLoaded;
   protected LoaderRegistry loaderRegistry;
   protected DynamicLibrary[] rootLibraries;
   protected DynamicLibrary[] cachedLibraries;
   protected DynamicLibrary[char[]] namespaceXref; // libraries by namespace
   protected DynamicLibrary[char[]] pathXref; // libraries by path
   protected Attributes attributes;
   protected FilePath root;
   protected char[] delegate(char[])[] namespaceTranslators;

   
   debug (DDL) protected void debugPathList(char[] prompt,FilePath[] list){
      debugLog("{0} ({1})\n",prompt,list.length);
       foreach(path; list){
          debugLog("  {0}\n",path.toString());
       }
   }
   
   protected DynamicLibrary[] getRootLibraries(){
	   if(!isPreLoaded){
		   root.toList(delegate bool(FilePath path_, bool isDirectory){
			   if(isDirectory) return 1;
			   auto path = path_.toString;
			   auto lib = loaderRegistry.load(path);
			   if(lib){
			      this.pathXref[path] = lib;
			      this.rootLibraries ~= lib;
			      this.cachedLibraries ~= lib;
		       }
		       return 1;
		   });
		   isPreLoaded = true;
	   }
	   return rootLibraries;
   }
   
	// attempts to load everything under the root path
	protected void loadEverything(){
		if(!isFullyLoaded){
			getRootLibraries();
			   
			// find directories to iterate, and files to load
			bool loadDelegate(FilePath path_, bool isDirectory){
			   auto path = path_.toString;
				if(isDirectory){
					(new FilePath(path_.folder)).toList(&loadDelegate);
				}
				else{
					if(path in this.pathXref) return 1; // skip already loaded libs
					auto lib = loaderRegistry.load(path);
					if(lib){
						this.pathXref[path] = lib; //TODO: strip extension
						this.cachedLibraries ~= lib;
					}
				}				
		        return 1;
			}
			
			// find directories to iterate through
			root.toList(delegate bool(FilePath path_, bool isDirectory){
				if(!isDirectory) return 1;
				(new FilePath(path_.folder)).toList(&loadDelegate);
				return 1;
			});
			
			isFullyLoaded = true;
		}
	}
      
   protected char[] convertNamespaceToPath(char[] namespace){
	   foreach_reverse(split,ch; namespace){
		   if(ch == '.'){
      			// process everything up to the last '.' - this is the true namespace
				return Text.replace(namespace[0..split],'.',FileConst.PathSeparatorChar);
		   }
	   }
       return "";
   }
   
   
   private static bool dSymbolStripType(char[] s, inout char[] res) {
		static char[][] prefixes = [
			"__nullext",
        	"_Dmain", "_DWinMain", "_D"
		];

      // TODO: strip the suffix ?
      foreach (char[] prefix; prefixes) {
         if (s.length > prefix.length && s[0 .. prefix.length] == prefix) {
            res = s[prefix.length .. length];
            return true;
         }
      }
   
      return false;
   }
         
   private static char[] parseNamespace(char[] symbolName) {
      char[] raw;
      if (!dSymbolStripType(symbolName, raw) || (raw[0] >= '0' && raw[0] <= '9')) {
         return symbolName;
      }
   
      char[] res;
      while (raw.length > 0 && (raw[0] >= '0' && raw[0] <= '9')) {
         int len = 0;
         while (raw.length > 0 && (raw[0] >= '0' && raw[0] <= '9')) {
            len *= 10;
            len += raw[0] - '0';
            raw = raw[1..$];
         }
         if (raw.length < len) {
            // invalid symbol ?
            return symbolName;
         }
   
         if (res.length) res ~= '.';
         res ~= raw[0 .. len];
         raw = raw[len .. $];
      }
   
      return res;
   }   
   
   private static char[] getParentNamespace(char[] name) {
	  foreach_reverse(idx,ch; name){
		  if(ch == '.'){
			  return name[0..idx];
		  }
	  }
	  return null;
   }
      
   unittest {
      static char[][2][] tests = [
         ["printf", "printf"],
         ["_foo", "_foo"],
         ["_D88", "_D88"],
         ["_D4test3fooAa", "test.foo"],
         ["_D8demangle8demangleFAaZAa", "demangle.demangle"],
         ["_D6object6Object8opEqualsFC6ObjectZi", "object.Object.opEquals"],
         ["_D4test2dgDFiYd", "test.dg"],
         ["_D4test58__T9factorialVde67666666666666860140VG5aa5_68656c6c6fVPvnZ9factorialf", "test.__T9factorialVde67666666666666860140VG5aa5_68656c6c6fVPvnZ.factorial"],
         ["_D4test101__T9factorialVde67666666666666860140Vrc9a999999999999d9014000000000000000c00040VG5aa5_68656c6c6fVPvnZ9factorialf","test.__T9factorialVde67666666666666860140Vrc9a999999999999d9014000000000000000c00040VG5aa5_68656c6c6fVPvnZ.factorial"],
         ["_D4test34__T3barVG3uw3_616263VG3wd3_646566Z1xi", "test.__T3barVG3uw3_616263VG3wd3_646566Z.x"]
      ];
   
   
      foreach (char[][2] t; tests) {
         assert (parseNamespace(t[0]) == t[1]);
      }      
      
      assert(getParentNamespace("std.stdio") == "std");
      assert(getParentNamespace("foo.bar.baz") == "foo.bar");
      assert(getParentNamespace("blah") is null);
   }
   
   
   public this(char[] rootPath,LoaderRegistry loaderRegistry, bool preloadRootLibs = true){
      this.root = new FilePath(rootPath);
      this.loaderRegistry = loaderRegistry;
      
      if (preloadRootLibs) {
      	getRootLibraries(); // trigger a load of the root libraries
      }
      
      addNamespaceTranslator(&convertNamespaceToPath);
      
      attributes["PATH.path"] = root.toString;
   }
         
   public void addNamespaceTranslator(char[] delegate(char[]) dg) {
      namespaceTranslators ~= dg;
   }   
   
   /+public override ExportSymbolPtr getSymbol(char[] name){
      DynamicModule mod = this.getModuleForSymbol(name);
      if(mod) return mod.getSymbol(name);
      return null;
   }+/
         
   public override DynamicModule[] getModules(){
      DynamicModule[] result;
      
      loadEverything();      
      foreach(lib; cachedLibraries){
	      result ~= lib.getModules();
      }
      return result;
   }
   
   public override char[] getType(){
      return "PATH";
   }
   
   public override char[][char[]] getAttributes(){
      return this.attributes;
   }

   public override ExportSymbolPtr getSymbol(char[] name){
      if(name.length > 2 && name[0..2] == "_D"){
         for (char[] namespace = parseNamespace(name); namespace !is null; namespace = getParentNamespace(namespace)) {
			// try a namespace lookup first
			DynamicLibrary* xrefLib = namespace in namespaceXref;
			if(xrefLib){
				return (*xrefLib).getSymbol(name);
			}       	         
	         
            // dig through the root libs   
            foreach(DynamicLibrary lib; getRootLibraries()){
               ExportSymbolPtr sym = lib.getSymbol(name);
               namespaceXref[namespace] = lib;
               if (sym !is &ExportSymbol.NONE) return sym;
            }
                        
            foreach (xlat; namespaceTranslators) {
		        char[] path = FilePath.join(this.root.toString(), xlat(namespace.dup));
	            if(isFullyLoaded){
		            //don't bother with path matching because we're already loaded
		            foreach(libPath,lib; pathXref){
			            if(libPath == path){
						   ExportSymbolPtr sym = lib.getSymbol(name);
						   namespaceXref[namespace] = lib;
						   if (sym !is &ExportSymbol.NONE) return sym;
			            }
		            }
	            }
	            else{
		           // look for a path match
		           if(path != ""){
			           auto test = new FilePath(path);
		              if (test.exists && !test.isFolder){
		                 DynamicLibrary lib = loaderRegistry.load(path);
		                 if(lib) {
		                    cachedLibraries ~= lib;
		                    namespaceXref[namespace] = lib;
		                    return lib.getSymbol(name);
		                 }
		              }
		              
		              //find first loadable library file that matches <root-path><path>/* and contains 'name'
		              ExportSymbolPtr sym;
		              (new FilePath(path)).toList(delegate bool(FilePath path_, bool isDirectory){
			             DynamicLibrary lib = loaderRegistry.load(path_.toString);
		                 if (lib) {
		                    cachedLibraries ~= lib;
		                    namespaceXref[namespace] = lib;
		                    sym = lib.getSymbol(name);
		                    return 0;
		                 }
		                 return 1;
		              });
		              return sym;
		           }
	           }
            }
         }
      }
      // match a non-D symbol
      else{
         // dig through the root libs
            foreach(DynamicLibrary lib; getRootLibraries()){
               auto sym = lib.getSymbol(name);
               if (sym !is &ExportSymbol.NONE) return sym;
            } 
      }
      //failed to find the module
      debug (DDL) debugLog("PathLibrary.getSymbol - failed to find: {0}",name);
      return null;
   }

   public override DynamicModule getModuleForSymbol(char[] name){
      if(name.length > 2 && name[0..2] == "_D"){
         for (char[] namespace = parseNamespace(name); namespace !is null; namespace = getParentNamespace(namespace)) {
			// try a namespace lookup first
			DynamicLibrary* xrefLib = namespace in namespaceXref;
			if(xrefLib){
				return (*xrefLib).getModuleForSymbol(name);
			}       	         
	         
            // dig through the root libs   
            foreach(DynamicLibrary lib; getRootLibraries()){
               DynamicModule mod = lib.getModuleForSymbol(name);
               namespaceXref[namespace] = lib;
               if(mod) return mod;
            }
                        
            foreach (xlat; namespaceTranslators) {
		        char[] path = FilePath.join(this.root.toString(), xlat(namespace.dup));
	            if(isFullyLoaded){
		            //don't bother with path matching because we're already loaded
		            foreach(libPath,lib; pathXref){
			            if(libPath == path){
			               DynamicModule mod = lib.getModuleForSymbol(name);
			               namespaceXref[namespace] = lib;
			               if(mod) return mod;
			            }
		            }
	            }
	            else{
		           // look for a path match
		           if(path != ""){
			           auto test = new FilePath(path);
		              if (test.exists && !test.isFolder){
		                 DynamicLibrary lib = loaderRegistry.load(path);
		                 if(lib) {
		                    cachedLibraries ~= lib;
		                    namespaceXref[namespace] = lib;
		                    return lib.getModuleForSymbol(name);
		                 }
		              }
		              
		              //find first loadable library file that matches <root-path><path>/* and contains 'name'
		              DynamicModule mod;
		              (new FilePath(path)).toList(delegate bool(FilePath path_, bool isDirectory){
			             DynamicLibrary lib = loaderRegistry.load(path_.toString);
		                 if(lib){
		                    cachedLibraries ~= lib;
		                    namespaceXref[namespace] = lib;
		                    mod = lib.getModuleForSymbol(name);
		                    return 0;
		                 }
		                 return 1;
		              });
		              return mod;
		           }
	           }
            }
         }
      }
      // match a non-D symbol
      else{
         // dig through the root libs
            foreach(DynamicLibrary lib; getRootLibraries()){
               DynamicModule mod = lib.getModuleForSymbol(name);
               if(mod) return mod;
            } 
      }
      //failed to find the module
      debug (DDL) debugLog("PathLibrary.getModuleForSymbol - failed to find: {0}",name);
      return null;
   }


   // expects resource in file-path format
   public override ubyte[] getResource(char[] name){
      File fc = new File(this.root.toString ~ name);
      ubyte[] data = new ubyte[fc.length];
      fc.read(data);
      return data;
   }
}
