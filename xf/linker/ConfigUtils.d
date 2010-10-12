module xf.linker.ConfigUtils;

private {
	import tango.text.Util : trim, triml, trimr, isSpace;
}


char[] cutOffWord(char[]* str) {
	*str = triml(*str);
	
	foreach (i, c; *str) {
		if (isSpace(c)) {
			auto res = (*str)[0..i];
			*str = trim((*str)[i+1..$]);
			return res;
		}
	}

	auto res = trimr(*str);
	*str = null;
	return res;
}
