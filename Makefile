DEPS=$(shell dub describe 2>/dev/null --data=source-files | sed "s/'//g")

./d1to2fix: $(DEPS)
	dub build

./d1to2fix_unittests: $(DEPS)
	dub build :unittests

.PHONY: all deb test-unittests test-output clean

test-output: ./d1to2fix
	./run_tests.d

test-unittests: ./d1to2fix_unittests
	./d1to2fix_unittests

test: test-unittests test-output

deb: ./d1to2fix
	./deb/build

all: ./d1to2fix

clean:
	$(RM) -r d1to2fix deb/*.deb .dub/
