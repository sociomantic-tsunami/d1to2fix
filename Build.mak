# rdmd will ignore modules in std package thus all libdparse
# modules copied from std.experimental have to be compiled
# explicitly in static library

STDSRC:=$(shell find $C/submodules -type f -name \*.d| grep src/std)
$B/libstdextra.a: $(STDSRC)
	$(call exec,$(DC) $(DFLAGS) -allinst -lib -of$@ $(STDSRC))

# main binary

$B/d1to2fix: override LDFLAGS += -L$B -lstdextra
$B/d1to2fix: $B/libstdextra.a $C/src/d1to2fix/main.d

all += $B/d1to2fix

# test

$O/%unittests: override LDFLAGS += -L$B -lstdextra
$O/%unittests: $B/libstdextra.a

.PHONY: deb
deb: $B/d1to2fix
	./deb/build
