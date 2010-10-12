/+
	Copyright (c) 2006 Eric Anderton
        
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
	DLL Loader for Windows support of OMF Implibs
	
	Authors: Eric Anderton
	License: BSD Derivative (see source for details)
	Copyright: 2006 Eric Anderton
*/
module ddl.omf.DLLProvider;

version(Windows){
	extern (Windows)
	{
		alias uint HANDLE;
		alias HANDLE HMODULE;
		alias int BOOL;
		alias int (*FARPROC)();
		alias void* LPCSTR;
		FARPROC GetProcAddress(HMODULE hModule, LPCSTR lpProcName);
		HMODULE LoadLibraryA(LPCSTR lpLibFileName);
		BOOL FreeLibrary(HMODULE hLibModule);
	}
	
	class DLLProvider{
		static HANDLE[char[]] dllHandles;
		static DLLProvider instance;
		
		public static this(){
			instance = new DLLProvider();
		}
		
		//TODO: is this valid? (is it guaranteed to be last?)
		public static ~this(){
			foreach(HANDLE handle; dllHandles){
				FreeLibrary(handle);
			}
		}
		
		public static HANDLE loadLibrary(char[] moduleName){
			synchronized(instance){
				HANDLE* pHandle = moduleName in dllHandles;
				HANDLE thisHandle;
				
				if(!pHandle){
					thisHandle = LoadLibraryA((cast(char[])moduleName~"\0").ptr);
					dllHandles[moduleName] = thisHandle;
				}
				else{
					thisHandle = *pHandle;
				}
				return thisHandle;
			}
		}
						
		public static void* loadModuleSymbol(char[] moduleName,char[] entryName){
			return GetProcAddress(loadLibrary(moduleName),(cast(char[])entryName~"\0").ptr);	
		}
		
		public static void* loadModuleSymbol(char[] moduleName,uint entryOrdinal){
			return GetProcAddress(loadLibrary(moduleName),cast(void*)entryOrdinal);
		}		
	}
}