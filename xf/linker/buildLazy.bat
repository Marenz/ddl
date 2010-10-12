del testLazy.exe
del plugin.lib

xfbuild testLazy.d LazyLinker.d -otestLazy -- -L/M -version=XfLinkerUnitTest -g -L/NOPACKFUNCTIONS -I../ext/ddl -I../.. -I../ext
rem rebuild -full -oqpobj -g -lib -O -release -L/NOPACKFUNCTIONS -ofplugin.lib plugin.d -I../.. -I../ext

testLazy
pause
