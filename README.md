# JESD204B-Transport-Layer

This is an implementation of JESD204B transport layer written in Verilog. The information and design is based off JEDEC JESD204B specification, which can be downloaded from [JEDEC](https://www.jedec.org/sites/default/files/docs/JESD204B.pdf) website.

## About JESD204B

This is a serialized interface between data converters (ADC/DAC) and logic devices (FPGA/ASIC). To further understand, this device specification has been divided into layers, including Application Layer, Transport Layer, Data Link Layer and Physical Layer. This repository will focus on the Transport Layer. Note that, I have another repository on the implementation of 8B/10B Encoder/Decoder, which is part of Data Link Layer section.

## JESD204B Transport Layer

The main purpose of JESD204B transport layer is to pack data based on link configurations:
*	It can add more information (control bits) about the transmitted data
*	It arranges data into octets, then into frames, before sending it as parallel data
The configuration is determined in the application layer, and will be passed to the transport layer as Verilog 'parameters' during module instantiation.

## Design Specification

The parameters that should be decided in application layer include L, M, N, N', CS, S (# of lanes, converters, resolution, sample size, control bits, samples). Further interpretation of this can be found in JEDEC specification. My design will determine TT (# of tail bits) and F (# of octets per frame) based on those configuration. 

Input data from converters are assumed to be concatenated, with least significant #resolution bits represents data from converter 0. Output data from lanes are also concatenated into 1 single bus, with least significant bits represents lane 0. 

## Key Features

This design of JESD204B Transport Layer supports these following configurations. Note that all of them have been and can be tested by changing the parameter in the testbench:
* Support 1-8 converters
* Support converter resolution of 10-16 bits
* Support 1-8 lanes
* Support 0-3 controls bits 

Odd input parameters for lanes and converters are also supported. Lanes that are not entirely filled with samples will be filled with TT (tail bits) instead.  

Converter resolution of 1-9 bits is supported as well, but it is usually not the case for a converter to have those resolutions. Therefore, they are omitted. 

## Constraints

The design assumes the sample size is 16 and each converter produces 1 sample per cycle for each frame, which is often to be the case. This limits the parameter of SAMPLE_SIZE and SAMPLES to be 16 and 1, though it can be changed in the code. Furthermore, due to these 2 constraints, values we pick for other parameters need to follow this rule:
* (Converter resolution + Control bits) ≤ 16
* L (# of lanes) ≤ M (# of converters)

