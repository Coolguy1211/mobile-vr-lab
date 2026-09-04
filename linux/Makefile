CXX ?= g++
CXXFLAGS ?= -std=c++17 -O2 -fPIC -Wall -Wextra -Wno-unused-parameter
INCLUDES = -Iopenxr/include
BUILD = build
LIB = $(BUILD)/libpocketvr_openxr_layer.so
MANIFEST = $(BUILD)/XR_APILAYER_POCKETVR_bridge.json

all: $(LIB) $(MANIFEST)

$(BUILD):
	mkdir -p $(BUILD)

$(LIB): pocketvr_openxr_layer.cpp | $(BUILD)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -shared $< -o $@

$(MANIFEST): pocketvr_openxr_layer.json.in $(LIB)
	python3 -c "from pathlib import Path; p=Path('pocketvr_openxr_layer.json.in').read_text().replace('@LIB@','./libpocketvr_openxr_layer.so'); Path('$(MANIFEST)').write_text(p)"

install-local: all
	mkdir -p $(HOME)/.local/lib $(HOME)/.local/share/openxr/1/api_layers/implicit.d
	cp $(LIB) $(HOME)/.local/lib/
	python3 -c "from pathlib import Path; p=Path('pocketvr_openxr_layer.json.in').read_text().replace('@LIB@',str(Path.home()/'.local/lib/libpocketvr_openxr_layer.so')); Path.home().joinpath('.local/share/openxr/1/api_layers/implicit.d/XR_APILAYER_POCKETVR_bridge.json').write_text(p)"

clean:
	rm -rf $(BUILD)
