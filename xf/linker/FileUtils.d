module xf.linker.FileUtils;

private {
	import tango.math.random.Kiss : Kiss;
	import tango.text.convert.Format;
	import tango.io.device.File : FileConduit = File;
	import tango.io.FilePath;
	import tango.core.Exception;
	import Path = tango.io.Path;
	import tango.sys.Common : SysError;
}



final scope class TmpFile {
	this(char[] root = ".") {
		for (int t = 0; t < 10000; ++t) {
			uint id = Kiss.instance.toInt();
			this._name = Path.join(root, Format("{}.tmp", id));
			if (FilePath(this._name).exists) {
				this._name = null;
				continue;
			} else {
				try {
					FilePath(this._name).createFile;
					break;
				} catch (IOException) {
					this._name = null;
					continue;
				}
			}
		}
		
		assert (this._name !is null, `could not create the file O_o`);
	}
	
	
	~this() {
		FilePath(this._name).remove;
		this._name = null;
	}
	
	
	char[] name() {
		return _name;
	}
	

	private {
		char[] _name;
	}
}




version (Windows) {
	// workaround for a bug in DMD < 1.035

	private import  tango.sys.Common;

	private static wchar[] toString16 (wchar[] tmp, char[] path)
	{
		auto i = MultiByteToWideChar (CP_UTF8, 0,
									  cast(PCHAR)path.ptr, path.length,
									  tmp.ptr, tmp.length-1);
		tmp[i] = 0;
		return tmp[0..i+1];
	}

	ulong fileModifiedTime(char[] name) {
		wchar[MAX_PATH+1] tmp = void;
		WIN32_FILE_ATTRIBUTE_DATA info;
		if (!GetFileAttributesExW(toString16(tmp, name).ptr, GetFileInfoLevelStandard, &info)) {
			throw new Exception("can't get time for file: " ~ name ~ " : " ~ SysError.lastMsg);
			return 0;
		}
		auto time = info.ftLastWriteTime;
		return (cast(ulong)time.dwHighDateTime << 32) + time.dwLowDateTime;
	}
} else {
	ulong fileModifiedTime(char[] name) {
		return FilePath(name).modified.ticks;
	}
}