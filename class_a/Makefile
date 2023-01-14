SDK_NRF_REVISION=v2.1-branch
SDK_NRF_REVISION?=latest
DOCKER_IMAGE_NAME=nordicplayground/nrfconnect-sdk
BOARD=nrf9160dk_nrf9160_ns
BOARD?=actinius_icarus_ns

USB_DEVICE=/dev/ttyUSB0

.PHONY: all
all: build flash

.PHONY: build
build:
	docker run --rm -v ${PWD}:/workdir/project \
		${DOCKER_IMAGE_NAME}:${SDK_NRF_REVISION} \
    west build -b ${BOARD}

.PHONY: build-pristine
build-pristine:
	docker run --rm -v ${PWD}:/workdir/project \
		${DOCKER_IMAGE_NAME}:${SDK_NRF_REVISION} \
    west build -p always -b ${BOARD}

.PHONY: flash
flash:
	docker run --rm -v ${PWD}:/workdir/project \
		--device=${USB_DEVICE} --privileged \
		${DOCKER_IMAGE_NAME}:${SDK_NRF_REVISION} \
		/bin/bash -c "pwd && echo && ls -l build/zephyr && mcumgr conn add icarus_dev type=\"serial\" connstring=\"${USB_DEVICE},baud=115200,mtu=512\" && \
		mcumgr image upload build/zephyr/app_update.bin -c icarus_dev"

.PHONY: shell
shell:
	docker run --rm -it -v ${PWD}:/workdir/project \
		--device=${USB_DEVICE} --privileged \
		${DOCKER_IMAGE_NAME}:${SDK_NRF_REVISION}

.PHONY: build-docker-image
build-docker-image:
	docker build -t ${DOCKER_IMAGE_NAME}:${SDK_NRF_REVISION} \
		--build-arg sdk_nrf_revision=${SDK_NRF_REVISION} .

