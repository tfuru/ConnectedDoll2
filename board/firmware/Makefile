.PHONY: build upload uploadfs monitor clean

patch-libs:
	@# ライブラリを事前にインストールさせる
	pio lib install
	@# ESP32-audioI2Sのminマクロ型競合コンパイルエラーを修正するパッチ (macOS/Linux両対応)
	@if [ -f .pio/libdeps/seeed_xiao_esp32c3/ESP32-audioI2S/src/Audio.cpp ]; then \
		echo "Patching ESP32-audioI2S/src/Audio.cpp..."; \
		sed -i.bak 's/availableBytes = min(availableBytes, InBuff.writeSpace());/availableBytes = min((size_t)availableBytes, InBuff.writeSpace());/g' .pio/libdeps/seeed_xiao_esp32c3/ESP32-audioI2S/src/Audio.cpp; \
	fi

build: patch-libs
	pio run


upload:
	pio run --target upload

uploadfs:
	pio run --target uploadfs

monitor:
	pio device monitor

clean:
	pio run --target clean
