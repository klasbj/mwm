from os.path import join;

# Initialize environment for GDC (D builder is setup to use dmd, and it
# treated linking weirdly...)
env = Environment(
          DC = 'gdc'
        , DCOM = '$DC $_DINCFLAGS $_DVERFLAGS $_DDEBUGFLAGS $_DFLAGS -c -o$TARGET $SOURCES'
        , DCOMSTR = 'Compiling $TARGET'
        , DFLAGS = ['g', 'Wall', 'funittest']
        , DLINK = 'gdc'
        , LINKCOM = '$DLINK -o$TARGET $SOURCES $_DFLAGS $DLINKFLAGS $_LIBDIRFLAGS $_LIBFLAGS'
        , LINKCOMSTR = 'Linking $TARGET'
        , LINKFLAGS = []
        , LIBS = []
        , ARCOMSTR = 'Archiving $TARGET'
        );

env.MergeFlags({ 'DPATH' : Split("""
        ../source
        ../xcb.d
        ../ZeroMQ
        ../msgpack-d/src
        """) });

env.MergeFlags('!pkg-config --libs xcb')
env.MergeFlags('!pkg-config --libs xcb-xinerama')
env.MergeFlags('!pkg-config --libs libzmq')
env.MergeFlags('-lpthread');

Export('env');

# Build everything in the build/ directory
VariantDir('build', '.', duplicate=0);

# Build msgpack-d and add it to the environment
msgpack_lib = env.Library('build/msgpack-d/msgpack', [join('build', 'msgpack-d','src','msgpack.d')]);
env.MergeFlags({'LIBS' : 'msgpack', 'LIBPATH' : ['build/msgpack-d']});

# Object files for the main program
objs = SConscript('build/source/SConscript');

# Put together the main program
env.Program('mwm', objs);


# vim: set ft=python sw=4 ts=4 :